import AVFoundation
import Flutter
import UIKit

final class M3u8IosPlayer: NSObject, FlutterTexture {
  var textureId: Int64 = -1 {
    didSet {
      displayLink?.isPaused = false
      sendInitializedIfReady()
    }
  }

  private let textureRegistry: FlutterTextureRegistry
  private let eventSinkProvider: () -> FlutterEventSink?
  private let player: AVPlayer
  private let playerItem: AVPlayerItem
  private let videoOutput: AVPlayerItemVideoOutput
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

  init(
    url: URL,
    headers: [String: String],
    textureRegistry: FlutterTextureRegistry,
    eventSinkProvider: @escaping () -> FlutterEventSink?
  ) {
    self.textureRegistry = textureRegistry
    self.eventSinkProvider = eventSinkProvider
    let assetOptions: [String: Any]? =
      headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
    let asset = AVURLAsset(url: url, options: assetOptions)
    self.playerItem = AVPlayerItem(asset: asset)
    self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    self.player = AVPlayer(playerItem: playerItem)
    super.init()
    diskCachePrefetcher = M3u8DiskCachePrefetcher(
      url: url,
      headers: headers,
      playerIdProvider: { [weak self] in self?.textureId ?? -1 },
      eventSinkProvider: eventSinkProvider
    )
    playerItem.add(videoOutput)
    player.actionAtItemEnd = .pause
    configureObservers()
    configureTimers()
    diskCachePrefetcher?.start()
  }

  func play() {
    guard !disposed else { return }
    player.play()
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
    player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { [weak self] _ in
      self?.sendProgress()
      self?.textureRegistry.textureFrameAvailable(self?.textureId ?? -1)
    }
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
    timeControlStatusObservation = nil
    statusObservation = nil
    loadedTimeRangesObservation = nil
    playbackLikelyToKeepUpObservation = nil
    rateObservation = nil
    player.pause()
    player.replaceCurrentItem(with: nil)
    playerItem.remove(videoOutput)
    latestPixelBuffer = nil
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard !disposed else { return nil }
    let hostTime = CACurrentMediaTime()
    let itemTime = videoOutput.itemTime(forHostTime: hostTime)
    if videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
      let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
    {
      latestPixelBuffer = pixelBuffer
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
    sendError(error)
  }

  private func configureObservers() {
    statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      switch item.status {
      case .readyToPlay:
        self.sendInitializedIfReady()
      case .failed:
        self.sendError(item.error as NSError?)
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

    timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.new]) {
      [weak self] player, _ in
      guard let self else { return }
      switch player.timeControlStatus {
      case .playing:
        self.sendPlaybackEvent("playing")
      case .paused:
        self.sendPlaybackEvent("paused")
      case .waitingToPlayAtSpecifiedRate:
        self.sendPlaybackEvent("buffering")
      @unknown default:
        break
      }
    }

    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      self?.sendPlaybackEvent(player.rate == 0 ? "paused" : "playing")
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

  private func sendInitializedIfReady() {
    guard !disposed, textureId >= 0, !initialized, playerItem.status == .readyToPlay else {
      return
    }
    let size = naturalSize()
    guard size.width > 0, size.height > 0 else { return }
    initialized = true
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
    sendEvent(playbackPayload(event: "progress"))
  }

  private func playbackPayload(event: String) -> [String: Any] {
    [
      "event": event,
      "position": milliseconds(from: player.currentTime()),
      "duration": milliseconds(from: playerItem.duration),
      "bufferedPosition": bufferedPositionMs(),
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
