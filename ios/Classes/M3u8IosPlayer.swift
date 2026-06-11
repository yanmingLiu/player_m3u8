import AVFoundation
import Flutter
import UIKit

enum M3u8SourceType {
  case auto
  case hls
  case progressive

  static func from(_ value: Any?) -> M3u8SourceType {
    guard let value = value as? String else { return .auto }
    switch value.lowercased() {
    case "hls":
      return .hls
    case "progressive":
      return .progressive
    default:
      return .auto
    }
  }

  func resolve(url: URL) -> M3u8SourceType {
    switch self {
    case .hls, .progressive:
      return self
    case .auto:
      switch url.pathExtension.lowercased() {
      case "mp4", "mov":
        return .progressive
      default:
        return .hls
      }
    }
  }

  var platformValue: String {
    switch self {
    case .auto:
      return "auto"
    case .hls:
      return "hls"
    case .progressive:
      return "progressive"
    }
  }
}

struct M3u8RecoveryPolicy {
  static let defaultRebufferThreshold = 3
  static let defaultMinimumRecoveryIntervalMs: Int64 = 10_000

  let isEnabled: Bool
  let rebufferThreshold: Int
  let minimumRecoveryInterval: TimeInterval
  let minimumAutoQualityHeight: Int

  static let defaults = M3u8RecoveryPolicy(
    isEnabled: true,
    rebufferThreshold: defaultRebufferThreshold,
    minimumRecoveryInterval: TimeInterval(defaultMinimumRecoveryIntervalMs) / 1000.0,
    minimumAutoQualityHeight: 0
  )

  static func from(_ map: [String: Any]?) -> M3u8RecoveryPolicy {
    guard let map else { return defaults }
    let intervalMs = (map["minimumRecoveryIntervalMs"] as? NSNumber)?.int64Value ??
      defaultMinimumRecoveryIntervalMs
    return M3u8RecoveryPolicy(
      isEnabled: map["isEnabled"] as? Bool ?? true,
      rebufferThreshold: max(
        (map["rebufferThreshold"] as? NSNumber)?.intValue ?? defaultRebufferThreshold,
        1
      ),
      minimumRecoveryInterval: max(TimeInterval(intervalMs) / 1000.0, 0),
      minimumAutoQualityHeight: max(
        (map["minimumAutoQualityHeight"] as? NSNumber)?.intValue ?? 0,
        0
      )
    )
  }
}

final class M3u8IosPlayer: NSObject, FlutterTexture, AVPlayerItemLegibleOutputPushDelegate {
  var textureId: Int64 = -1 {
    didSet {
      displayLink?.isPaused = false
      sendInitializedIfReady()
    }
  }

  private let textureRegistry: FlutterTextureRegistry
  private let eventSinkProvider: () -> FlutterEventSink?
  private let videoUrl: URL
  private let audioUrl: URL?
  private let videoHeaders: [String: String]
  private let audioHeaders: [String: String]?
  private let cacheKey: String?
  private let sourceType: M3u8SourceType
  private var asset: AVURLAsset
  private let player: AVPlayer
  private var playerItem: AVPlayerItem
  private var videoOutput: AVPlayerItemVideoOutput
  private var legibleOutput: AVPlayerItemLegibleOutput
  private let resourceLoader: M3u8ResourceLoader
  private var diskCachePrefetcher: M3u8DiskCachePrefetcher?
  private var displayLink: CADisplayLink?
  private var progressTimer: Timer?
  private var timeControlStatusObservation: NSKeyValueObservation?
  private var statusObservation: NSKeyValueObservation?
  private var loadedTimeRangesObservation: NSKeyValueObservation?
  private var playbackLikelyToKeepUpObservation: NSKeyValueObservation?
  private var rateObservation: NSKeyValueObservation?
  private var latestPixelBuffer: CVPixelBuffer?
  private var disposed = false
  private var initialized = false
  private let createdAt = Date()
  private var startupTimeMs: Int64 = 0
  private var rebufferCount = 0
  private var rebufferDurationMs: Int64 = 0
  private var rebufferStartedAt: Date?
  private var droppedFrames = 0
  private var videoBitrate = 0
  private var observedBitrate = 0
  private var qualitySwitchCount = 0
  private var wasLikelyPlayingBeforeWaiting = false
  private var availableQualities = [[String: Any]]()
  private var selectedQuality: [String: Any] = M3u8IosPlayer.autoQuality()
  private var availableSubtitles: [[String: Any]]
  private var selectedSubtitleId: String?
  private var selectedSubtitle: [String: Any]?
  private var subtitleText = ""
  private var availableAudioTracks = [[String: Any]]()
  private var selectedAudioTrackId: String?
  private var selectedAudioTrack: [String: Any]?
  private var playbackSpeed: Double
  private var volume: Double
  private var isMuted: Bool
  private var recoveryPolicy: M3u8RecoveryPolicy
  private var recoveryCount = 0
  private var lastRecoveryReason = ""
  private var lastRecoveredRebufferCount = 0
  private var lastRecoveryAt = Date.distantPast

  var supportsQualitySelection: Bool { sourceType == .hls }

  init(
    videoUrl: URL,
    audioUrl: URL?,
    videoHeaders: [String: String],
    audioHeaders: [String: String]?,
    cacheKey: String?,
    sourceType: M3u8SourceType,
    initialPositionMs: Int64,
    playbackSpeed: Double,
    volume: Double,
    isMuted: Bool,
    externalSubtitles: [[String: Any]],
    selectedSubtitleId: String?,
    selectedAudioTrackId: String?,
    recoveryPolicy: M3u8RecoveryPolicy,
    textureRegistry: FlutterTextureRegistry,
    eventSinkProvider: @escaping () -> FlutterEventSink?
  ) {
    self.textureRegistry = textureRegistry
    self.eventSinkProvider = eventSinkProvider
    self.videoUrl = videoUrl
    self.audioUrl = audioUrl
    self.videoHeaders = videoHeaders
    self.audioHeaders = audioHeaders
    self.cacheKey = cacheKey
    let resolvedSourceType = sourceType.resolve(url: videoUrl)
    self.sourceType = resolvedSourceType
    self.playbackSpeed = min(max(playbackSpeed, 0.25), 2.0)
    self.volume = min(max(volume, 0), 1)
    self.isMuted = isMuted
    self.availableSubtitles = resolvedSourceType == .hls
      ? Self.normalizeExternalSubtitles(externalSubtitles)
      : []
    self.selectedSubtitleId = selectedSubtitleId
    self.selectedSubtitle = availableSubtitles.first { $0["id"] as? String == selectedSubtitleId }
    self.selectedAudioTrackId = selectedAudioTrackId
    let effectiveAudioHeaders = audioHeaders ?? videoHeaders
    self.recoveryPolicy = recoveryPolicy
    self.resourceLoader = M3u8ResourceLoader(
      headers: videoHeaders,
      cacheKey: cacheKey,
      audioUrl: audioUrl,
      audioHeaders: effectiveAudioHeaders,
      externalSubtitles: self.availableSubtitles,
    )
    let assetOptions: [String: Any]? =
      videoHeaders.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": videoHeaders]
    let asset = AVURLAsset(
      url: Self.assetUrl(
        for: videoUrl,
        sourceType: self.sourceType,
        headers: videoHeaders,
        cacheKey: cacheKey
      ),
      options: assetOptions
    )
    self.asset = asset
    if self.sourceType == .hls {
      self.asset.resourceLoader.setDelegate(resourceLoader, queue: DispatchQueue.main)
    }
    self.playerItem = AVPlayerItem(asset: self.asset)
    self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    self.legibleOutput = AVPlayerItemLegibleOutput()
    self.player = AVPlayer(playerItem: playerItem)
    self.player.volume = Float(self.volume)
    self.player.isMuted = isMuted
    super.init()
    resourceLoader.qualityProvider = { [weak self] in
      self?.selectedQuality ?? Self.autoQuality()
    }
    if self.sourceType == .hls {
      loadAvailableQualities()
    } else {
      availableQualities = []
    }
    if initialPositionMs > 0 {
      let seconds = Double(initialPositionMs) / 1000.0
      player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
    if self.sourceType == .hls {
      diskCachePrefetcher = M3u8DiskCachePrefetcher(
        url: videoUrl,
        headers: videoHeaders,
        cacheKey: cacheKey,
        playerIdProvider: { [weak self] in self?.textureId ?? -1 },
        eventSinkProvider: eventSinkProvider,
        qualityProvider: { [weak self] in self?.selectedQuality ?? Self.autoQuality() },
        audioUrl: audioUrl,
        audioHeaders: effectiveAudioHeaders,
      )
    } else {
      diskCachePrefetcher = nil
    }
    playerItem.add(videoOutput)
    legibleOutput.setDelegate(self, queue: DispatchQueue.main)
    playerItem.add(legibleOutput)
    player.actionAtItemEnd = .pause
    configureObservers()
    configureTimers()
    diskCachePrefetcher?.restart(from: initialPositionMs)
  }

  func play() {
    guard !disposed else { return }
    player.rate = Float(playbackSpeed)
    sendPlaybackEvent("playing")
  }

  func pause() {
    guard !disposed else { return }
    player.pause()
    sendPlaybackEvent("paused")
  }

  func seek(to positionMs: Int64) {
    guard !disposed else { return }
    let seconds = Double(max(positionMs, 0)) / 1000.0
    diskCachePrefetcher?.restart(from: positionMs)
    player.seek(
      to: CMTime(seconds: seconds, preferredTimescale: 600),
      toleranceBefore: CMTime(seconds: 3, preferredTimescale: 600),
      toleranceAfter: .zero
    ) { [weak self] _ in
      self?.sendProgress()
      self?.textureRegistry.textureFrameAvailable(self?.textureId ?? -1)
    }
  }

  func setQuality(_ quality: [String: Any]) {
    guard !disposed, sourceType == .hls else { return }
    selectedQuality = (quality["isAuto"] as? Bool ?? false)
      ? Self.autoQuality()
      : Self.qualityPayload(
        width: quality["width"] as? Int ?? 0,
        height: quality["height"] as? Int ?? 0,
        bitrate: quality["bitrate"] as? Int ?? 0
      )
    qualitySwitchCount += 1
    let position = player.currentTime()
    let shouldPlay = player.rate > 0
    replacePlayerItem()
    diskCachePrefetcher?.restart(from: milliseconds(from: position))
    player.seek(to: position) { [weak self] _ in
      if shouldPlay {
        self?.player.rate = Float(self?.playbackSpeed ?? 1.0)
      }
      self?.sendProgress()
    }
  }

  func setRecoveryPolicy(_ policy: M3u8RecoveryPolicy) {
    guard !disposed else { return }
    recoveryPolicy = policy
    sendProgress()
  }

  func setPlaybackSpeed(_ speed: Double) {
    guard !disposed else { return }
    playbackSpeed = min(max(speed, 0.25), 2.0)
    if player.rate > 0 || player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
      player.rate = Float(playbackSpeed)
    }
    sendProgress()
  }

  func setVolume(_ volume: Double) {
    guard !disposed else { return }
    self.volume = min(max(volume, 0), 1)
    player.volume = Float(self.volume)
    sendProgress()
  }

  func setMuted(_ isMuted: Bool) {
    guard !disposed else { return }
    self.isMuted = isMuted
    player.isMuted = isMuted
    sendProgress()
  }

  func setSubtitle(_ subtitleId: String?) {
    guard !disposed else { return }
    selectedSubtitleId = subtitleId
    selectedSubtitle = availableSubtitles.first { $0["id"] as? String == subtitleId }
    subtitleText = ""
    applySelectedSubtitle()
    var payload = playbackPayload(event: "progress")
    payload["subtitleText"] = ""
    sendEvent(payload)
  }

  func setAudioTrack(_ audioTrackId: String?) {
    guard !disposed else { return }
    selectedAudioTrackId = audioTrackId
    selectedAudioTrack = availableAudioTracks.first { $0["id"] as? String == audioTrackId }
    applySelectedAudioTrack()
    sendEvent(playbackPayload(event: "progress"))
  }

  func dispose() {
    guard !disposed else { return }
    disposed = true
    diskCachePrefetcher?.cancel()
    diskCachePrefetcher = nil
    progressTimer?.invalidate()
    progressTimer = nil
    displayLink?.invalidate()
    displayLink = nil
    NotificationCenter.default.removeObserver(self)
    clearItemObservers()
    timeControlStatusObservation = nil
    rateObservation = nil
    player.pause()
    player.replaceCurrentItem(with: nil)
    asset.resourceLoader.setDelegate(nil, queue: nil)
    playerItem.remove(legibleOutput)
    playerItem.remove(videoOutput)
    latestPixelBuffer = nil
  }

  func legibleOutput(
    _ output: AVPlayerItemLegibleOutput,
    didOutput attributedStrings: [NSAttributedString],
    nativeSampleBuffers: [Any],
    forItemTime itemTime: CMTime
  ) {
    subtitleText = attributedStrings
      .map { $0.string.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    var payload = playbackPayload(event: "progress")
    payload["subtitleText"] = subtitleText
    sendEvent(payload)
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard !disposed else { return nil }
    let hostTime = CACurrentMediaTime()
    let itemTime = videoOutput.itemTime(forHostTime: hostTime)
    if videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
      let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
    {
      latestPixelBuffer = pixelBuffer
      if startupTimeMs == 0 {
        startupTimeMs = max(Int64(Date().timeIntervalSince(createdAt) * 1000), 0)
        sendProgress()
      }
      if !initialized {
        sendInitializedIfReady()
      }
    }

    guard let latestPixelBuffer else { return nil }
    return Unmanaged.passRetained(latestPixelBuffer)
  }

  func onTextureUnregistered(_ texture: FlutterTexture) {
    DispatchQueue.main.async { [weak self] in
      self?.dispose()
    }
  }

  @objc private func displayLinkFired() {
    guard !disposed, textureId >= 0 else { return }
    textureRegistry.textureFrameAvailable(textureId)
  }

  @objc private func progressTimerFired() {
    sendProgress()
  }

  @objc private func didPlayToEnd() {
    sendPlaybackEvent("completed")
  }

  @objc private func didFailToEnd(notification: Notification) {
    let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
    if !attemptRecovery(reason: "error:\(error?.domain ?? "playback")") {
      sendError(error)
    }
  }

  private func configureObservers() {
    configureItemObservers()

    timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.new]) {
      [weak self] player, _ in
      guard let self else { return }
      switch player.timeControlStatus {
      case .playing:
        self.finishRebufferTiming()
        self.wasLikelyPlayingBeforeWaiting = true
        self.sendPlaybackEvent("playing")
      case .paused:
        self.finishRebufferTiming()
        self.wasLikelyPlayingBeforeWaiting = false
        self.sendPlaybackEvent("paused")
      case .waitingToPlayAtSpecifiedRate:
        if self.initialized && self.wasLikelyPlayingBeforeWaiting {
          self.rebufferCount += 1
          if self.rebufferStartedAt == nil {
            self.rebufferStartedAt = Date()
          }
          if self.recoveryPolicy.isEnabled &&
            self.rebufferCount - self.lastRecoveredRebufferCount >=
            self.recoveryPolicy.rebufferThreshold
          {
            _ = self.attemptRecovery(reason: "rebuffer")
          }
        }
        self.sendPlaybackEvent("buffering")
      @unknown default:
        break
      }
    }

    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      self?.sendPlaybackEvent(player.rate == 0 ? "paused" : "playing")
    }
  }

  private func configureItemObservers() {
    statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      switch item.status {
      case .readyToPlay:
        self.sendInitializedIfReady()
      case .failed:
        let error = item.error as NSError?
        self.finishRebufferTiming()
        if !self.attemptRecovery(reason: "error:\(error?.domain ?? "playback")") {
          self.sendError(error)
        }
      case .unknown:
        break
      @unknown default:
        break
      }
    }

    loadedTimeRangesObservation = playerItem.observe(\.loadedTimeRanges, options: [.new]) {
      [weak self] _, _ in
      self?.sendProgress()
    }

    playbackLikelyToKeepUpObservation = playerItem.observe(
      \.isPlaybackLikelyToKeepUp,
      options: [.new]
    ) { [weak self] item, _ in
      guard let self else { return }
      if item.isPlaybackLikelyToKeepUp {
        self.sendPlaybackEvent(self.player.rate == 0 ? "paused" : "playing")
      } else {
        self.sendPlaybackEvent("buffering")
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didPlayToEnd),
      name: .AVPlayerItemDidPlayToEndTime,
      object: playerItem
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didFailToEnd(notification:)),
      name: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem
    )
  }

  private func clearItemObservers() {
    statusObservation = nil
    loadedTimeRangesObservation = nil
    playbackLikelyToKeepUpObservation = nil
    NotificationCenter.default.removeObserver(
      self,
      name: .AVPlayerItemDidPlayToEndTime,
      object: playerItem
    )
    NotificationCenter.default.removeObserver(
      self,
      name: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem
    )
  }

  private func replacePlayerItem() {
    clearItemObservers()
    playerItem.remove(videoOutput)
    playerItem.remove(legibleOutput)
    asset.resourceLoader.setDelegate(nil, queue: nil)
    let assetOptions: [String: Any]? =
      videoHeaders.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": videoHeaders]
    asset = AVURLAsset(
      url: Self.assetUrl(
        for: videoUrl,
        sourceType: sourceType,
        headers: videoHeaders,
        cacheKey: cacheKey
      ),
      options: assetOptions
    )
    if sourceType == .hls {
      asset.resourceLoader.setDelegate(resourceLoader, queue: DispatchQueue.main)
    }
    playerItem = AVPlayerItem(asset: asset)
    videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    legibleOutput = AVPlayerItemLegibleOutput()
    legibleOutput.setDelegate(self, queue: DispatchQueue.main)
    playerItem.add(videoOutput)
    playerItem.add(legibleOutput)
    player.replaceCurrentItem(with: playerItem)
    initialized = false
    latestPixelBuffer = nil
    configureItemObservers()
    applySelectedSubtitle()
  }

  private func configureTimers() {
    displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
    displayLink?.add(to: .main, forMode: .common)
    progressTimer = Timer.scheduledTimer(
      timeInterval: 0.25,
      target: self,
      selector: #selector(progressTimerFired),
      userInfo: nil,
      repeats: true
    )
  }

  private func loadAvailableQualities() {
    guard sourceType == .hls else {
      availableQualities = []
      return
    }
    guard let data = try? M3u8IosCacheManager.shared.data(for: videoUrl, headers: videoHeaders),
      let text = String(data: data, encoding: .utf8)
    else {
      availableQualities = []
      return
    }
    var qualities: [[String: Any]] = []
    for rawLine in text.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard line.hasPrefix("#EXT-X-STREAM-INF:") else { continue }
      let resolution = parseAttribute(line, name: "RESOLUTION")
      let parts = resolution?.split(separator: "x")
      let width = Int(parts?.first ?? "") ?? 0
      let height = Int(parts?.last ?? "") ?? 0
      let bitrate = Int(parseAttribute(line, name: "BANDWIDTH") ?? "") ?? 0
      qualities.append(Self.qualityPayload(width: width, height: height, bitrate: bitrate))
    }
    var seen = Set<String>()
    availableQualities = qualities
      .filter { quality in
        let id = quality["id"] as? String ?? "unknown"
        guard !seen.contains(id) else { return false }
        seen.insert(id)
        return true
      }
      .sorted {
        (($0["height"] as? Int ?? 0), ($0["bitrate"] as? Int ?? 0)) >
          (($1["height"] as? Int ?? 0), ($1["bitrate"] as? Int ?? 0))
      }
  }

  private func sendInitializedIfReady() {
    guard !disposed, textureId >= 0, !initialized, playerItem.status == .readyToPlay else {
      return
    }
    let size = naturalSize()
    guard size.width > 0, size.height > 0 else { return }
    initialized = true
    updateQualityMetrics()
    updateAvailableSubtitles()
    applySelectedSubtitle()
    var payload = playbackPayload(event: "initialized")
    payload["width"] = size.width
    payload["height"] = size.height
    sendEvent(payload)
  }

  private func naturalSize() -> CGSize {
    if let track = playerItem.asset.tracks(withMediaType: .video).first {
      let transformedSize = track.naturalSize.applying(track.preferredTransform)
      return CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
    }
    if let latestPixelBuffer {
      return CGSize(
        width: CVPixelBufferGetWidth(latestPixelBuffer),
        height: CVPixelBufferGetHeight(latestPixelBuffer)
      )
    }
    return .zero
  }

  private func sendPlaybackEvent(_ event: String) {
    sendEvent(playbackPayload(event: event))
  }

  private func sendProgress() {
    updateQualityMetrics()
    sendEvent(playbackPayload(event: "progress"))
  }

  private func playbackPayload(event: String) -> [String: Any] {
    [
      "event": event,
      "position": milliseconds(from: player.currentTime()),
      "duration": milliseconds(from: playerItem.duration),
      "bufferedPosition": bufferedPositionMs(),
      "startupTime": startupTimeMs,
      "rebufferCount": rebufferCount,
      "rebufferDuration": currentRebufferDurationMs(),
      "droppedFrames": droppedFrames,
      "videoBitrate": videoBitrate,
      "observedBitrate": observedBitrate,
      "qualitySwitchCount": qualitySwitchCount,
      "availableQualities": availableQualities,
      "selectedQuality": selectedQuality,
      "playbackSpeed": playbackSpeed,
      "volume": volume,
      "isMuted": isMuted,
      "availableSubtitles": availableSubtitles,
      "selectedSubtitle": selectedSubtitle as Any,
      "subtitleText": subtitleText,
      "availableAudioTracks": availableAudioTracks,
      "selectedAudioTrack": selectedAudioTrack as Any,
      "recoveryCount": recoveryCount,
      "lastRecoveryReason": lastRecoveryReason,
    ]
  }

  private func attemptRecovery(reason: String) -> Bool {
    guard recoveryPolicy.isEnabled else { return false }
    guard Date().timeIntervalSince(lastRecoveryAt) >= recoveryPolicy.minimumRecoveryInterval else {
      return false
    }
    guard let lowerQuality = nextLowerQuality() else { return false }
    let position = player.currentTime()
    let shouldPlay = player.rate > 0 || player.timeControlStatus == .waitingToPlayAtSpecifiedRate
    recoveryCount += 1
    lastRecoveryReason = reason
    lastRecoveredRebufferCount = rebufferCount
    lastRecoveryAt = Date()
    selectedQuality = lowerQuality
    qualitySwitchCount += 1
    NSLog(
      "player_m3u8 recover playerId=\(textureId) reason=\(reason) quality=\(lowerQuality["id"] ?? "unknown")"
    )
    replacePlayerItem()
    diskCachePrefetcher?.restart(from: milliseconds(from: position))
    player.seek(to: position) { [weak self] _ in
      if shouldPlay {
        self?.player.rate = Float(self?.playbackSpeed ?? 1.0)
      }
      self?.sendProgress()
    }
    return true
  }

  private func nextLowerQuality() -> [String: Any]? {
    guard !availableQualities.isEmpty else { return nil }
    let isAuto = selectedQuality["isAuto"] as? Bool ?? false
    let currentSize = naturalSize()
    let currentHeight = isAuto
      ? (currentSize.height > 0 ? Int(currentSize.height) : Int.max)
      : selectedQuality["height"] as? Int ?? Int.max
    let currentBitrate = isAuto
      ? (videoBitrate > 0 ? videoBitrate : Int.max)
      : selectedQuality["bitrate"] as? Int ?? Int.max
    return availableQualities
      .filter { quality in
        let height = quality["height"] as? Int ?? 0
        let bitrate = quality["bitrate"] as? Int ?? 0
        return (height > 0 || bitrate > 0) &&
          (isAuto || height < currentHeight || (height == currentHeight && bitrate < currentBitrate)) &&
          (recoveryPolicy.minimumAutoQualityHeight <= 0 ||
            height <= 0 ||
            height >= recoveryPolicy.minimumAutoQualityHeight)
      }
      .max { lhs, rhs in
        let lhsHeight = lhs["height"] as? Int ?? 0
        let rhsHeight = rhs["height"] as? Int ?? 0
        if lhsHeight != rhsHeight {
          return lhsHeight < rhsHeight
        }
        return (lhs["bitrate"] as? Int ?? 0) < (rhs["bitrate"] as? Int ?? 0)
      }
  }

  private func updateQualityMetrics() {
    if let track = playerItem.asset.tracks(withMediaType: .video).first {
      let bitrate = Int(track.estimatedDataRate)
      if bitrate > 0 {
        videoBitrate = bitrate
      }
    }
    if let accessLogEvent = playerItem.accessLog()?.events.last {
      let observed = Int(accessLogEvent.observedBitrate)
      if observed > 0 {
        observedBitrate = observed
      }
    }
  }

  private func updateAvailableSubtitles() {
    var merged: [String: [String: Any]] = [:]
    for subtitle in availableSubtitles {
      if let id = subtitle["id"] as? String {
        merged[id] = subtitle
      }
    }
    guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
      availableSubtitles = Array(merged.values)
      selectedSubtitle = selectedSubtitleId.flatMap { merged[$0] }
      return
    }
    for (index, option) in group.options.enumerated() {
      let id = option.propertyList() as? String ?? "legible:\(index)"
      let language = option.locale?.identifier
      let label = option.displayName
      merged[id] = [
        "id": id,
        "label": label.isEmpty ? (language ?? "Subtitle \(index + 1)") : label,
        "language": language as Any,
        "url": NSNull(),
        "mimeType": NSNull(),
        "headers": [:],
      ]
    }
    availableSubtitles = Array(merged.values).sorted {
      ($0["label"] as? String ?? "") < ($1["label"] as? String ?? "")
    }
    selectedSubtitle = selectedSubtitleId.flatMap { merged[$0] }
  }

  private func applySelectedSubtitle() {
    updateAvailableSubtitles()
    guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
      selectedSubtitle = nil
      return
    }
    guard let subtitleId = selectedSubtitleId else {
      playerItem.select(nil, in: group)
      selectedSubtitle = nil
      return
    }
    for (index, option) in group.options.enumerated() {
      let id = option.propertyList() as? String ?? "legible:\(index)"
      if id == subtitleId {
        playerItem.select(option, in: group)
        selectedSubtitle = [
          "id": id,
          "label": option.displayName,
          "language": option.locale?.identifier as Any,
          "url": NSNull(),
          "mimeType": NSNull(),
          "headers": [:],
        ]
        return
      }
    }
    selectedSubtitle = nil
  }

  private func updateAvailableAudioTracks() {
    guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
      return
    }
    var tracks = [[String: Any]]()
    for (index, option) in group.options.enumerated() {
      let id = option.propertyList() as? String ?? "audible:\(index)"
      let language = option.locale?.identifier
      let label = option.displayName
      tracks.append([
        "id": id,
        "label": label.isEmpty ? (language ?? "Audio \(index + 1)") : label,
        "language": language as Any,
        "url": NSNull(),
        "mimeType": NSNull(),
        "headers": [:],
      ])
    }
    availableAudioTracks = tracks
    selectedAudioTrack = selectedAudioTrackId.flatMap { id in
      tracks.first { $0["id"] as? String == id }
    }
  }

  private func applySelectedAudioTrack() {
    updateAvailableAudioTracks()
    guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
      selectedAudioTrack = nil
      return
    }
    guard let audioTrackId = selectedAudioTrackId else {
      playerItem.select(nil, in: group)
      selectedAudioTrack = nil
      return
    }
    for (index, option) in group.options.enumerated() {
      let id = option.propertyList() as? String ?? "audible:\(index)"
      if id == audioTrackId {
        playerItem.select(option, in: group)
        selectedAudioTrack = [
          "id": id,
          "label": option.displayName,
          "language": option.locale?.identifier as Any,
          "url": NSNull(),
          "mimeType": NSNull(),
          "headers": [:],
        ]
        return
      }
    }
    selectedAudioTrack = nil
  }

  private func finishRebufferTiming() {
    guard let startedAt = rebufferStartedAt else { return }
    rebufferDurationMs += max(Int64(Date().timeIntervalSince(startedAt) * 1000), 0)
    rebufferStartedAt = nil
  }

  private func currentRebufferDurationMs() -> Int64 {
    guard let startedAt = rebufferStartedAt else { return rebufferDurationMs }
    return rebufferDurationMs + max(Int64(Date().timeIntervalSince(startedAt) * 1000), 0)
  }

  private func parseAttribute(_ line: String, name: String) -> String? {
    let pattern = "\(name)=([^,]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard
      let match = regex.firstMatch(in: line, range: range),
      let valueRange = Range(match.range(at: 1), in: line)
    else {
      return nil
    }
    return String(line[valueRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
  }

  private static func autoQuality() -> [String: Any] {
    [
      "id": "auto",
      "label": "Auto",
      "width": 0,
      "height": 0,
      "bitrate": 0,
      "isAuto": true,
    ]
  }

  private static func normalizeExternalSubtitles(_ subtitles: [[String: Any]]) -> [[String: Any]] {
    subtitles.enumerated().map { index, subtitle in
      let id = (subtitle["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ??
        (subtitle["language"] as? String).flatMap { $0.isEmpty ? nil : $0 } ??
        "external:\(index)"
      let label = (subtitle["label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ??
        (subtitle["language"] as? String).flatMap { $0.isEmpty ? nil : $0 } ??
        "Subtitle \(index + 1)"
      return [
        "id": id,
        "label": label,
        "language": subtitle["language"] as Any,
        "url": subtitle["url"] as Any,
        "mimeType": subtitle["mimeType"] as Any,
        "headers": subtitle["headers"] as? [String: String] ?? [:],
      ]
    }
  }

  private static func assetUrl(
    for url: URL,
    sourceType: M3u8SourceType,
    headers: [String: String],
    cacheKey: String?
  ) -> URL {
    if sourceType == .hls {
      return M3u8ResourceLoader.cachedUrl(for: url)
    }
    return M3u8IosCacheManager.shared.cachedFileIfExists(
      for: url,
      headers: headers,
      cacheKey: cacheKey
    ) ?? url
  }

  private static func qualityPayload(width: Int, height: Int, bitrate: Int) -> [String: Any] {
    let label: String
    let id: String
    if height > 0 {
      label = "\(height)p"
      id = "\(height)p"
    } else if bitrate > 0 {
      label = "\(bitrate / 1000) Kbps"
      id = "\(bitrate)bps"
    } else {
      label = "Unknown"
      id = "unknown"
    }
    return [
      "id": id,
      "label": label,
      "width": max(width, 0),
      "height": max(height, 0),
      "bitrate": max(bitrate, 0),
      "isAuto": false,
    ]
  }

  private func bufferedPositionMs() -> Int64 {
    guard let range = playerItem.loadedTimeRanges.first?.timeRangeValue else { return 0 }
    let bufferedEnd = CMTimeGetSeconds(CMTimeAdd(range.start, range.duration))
    if bufferedEnd.isFinite {
      return max(Int64(bufferedEnd * 1000), 0)
    }
    return 0
  }

  private func milliseconds(from time: CMTime) -> Int64 {
    let seconds = CMTimeGetSeconds(time)
    guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return 0 }
    return Int64(seconds * 1000)
  }

  private func sendError(_ error: NSError?) {
    sendEvent([
      "event": "error",
      "error": [
        "code": error?.domain ?? "playback_error",
        "message": error?.localizedDescription ?? "Playback failed.",
        "details": error?.userInfo.description,
      ],
    ])
  }

  private func sendEvent(_ payload: [String: Any]) {
    guard !disposed, textureId >= 0 else { return }
    var event = payload
    event["playerId"] = textureId
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.disposed else { return }
      self.eventSinkProvider()?(event)
    }
  }
}
