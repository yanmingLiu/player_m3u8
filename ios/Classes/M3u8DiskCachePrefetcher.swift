import Flutter
import Foundation

final class M3u8DiskCachePrefetcher {
  private let url: URL
  private let headers: [String: String]
  private let audioUrl: URL?
  private let audioHeaders: [String: String]?
  private let playerIdProvider: () -> Int64
  private let eventSinkProvider: () -> FlutterEventSink?
  private let cacheManager: M3u8IosCacheManager
  private let taskId: String?
  private let onFinished: (() -> Void)?
  private let qualityProvider: () -> [String: Any]
  private let queue = DispatchQueue(label: "player_m3u8_disk_cache")
  private let lock = NSLock()
  private var cancelled = false
  private var generation = 0
  private var currentTask: URLSessionTask?
  private var playlist: Playlist?
  private var playlistQualityKey: String?

  init(
    url: URL,
    headers: [String: String],
    playerIdProvider: @escaping () -> Int64,
    eventSinkProvider: @escaping () -> FlutterEventSink?,
    taskId: String? = nil,
    onFinished: (() -> Void)? = nil,
    qualityProvider: (() -> [String: Any])? = nil,
    cacheManager: M3u8IosCacheManager = .shared,
    audioUrl: URL? = nil,
    audioHeaders: [String: String]? = nil
  ) {
    self.url = url
    self.headers = headers
    self.audioUrl = audioUrl
    self.audioHeaders = audioHeaders
    self.playerIdProvider = playerIdProvider
    self.eventSinkProvider = eventSinkProvider
    self.taskId = taskId
    self.onFinished = onFinished
    self.qualityProvider = qualityProvider ?? { M3u8DiskCachePrefetcher.autoQuality() }
    self.cacheManager = cacheManager
  }

  func start() {
    restart(from: 0)
  }

  func restart(from positionMs: Int64) {
    lock.lock()
    guard !cancelled else {
      lock.unlock()
      return
    }
    generation += 1
    let taskGeneration = generation
    let task = currentTask
    lock.unlock()
    task?.cancel()
    queue.async { [weak self] in
      self?.cacheVod(startPositionMs: max(positionMs, 0), generation: taskGeneration)
    }
  }

  func cancel() {
    lock.lock()
    cancelled = true
    generation += 1
    let task = currentTask
    lock.unlock()
    task?.cancel()
  }

  private func cacheVod(startPositionMs: Int64, generation taskGeneration: Int) {
    do {
      let selectedQuality = normalizeQuality(qualityProvider())
      let selectedQualityKey = qualityKey(selectedQuality)
      let playlist: Playlist
      if let cachedPlaylist = self.playlist, playlistQualityKey == selectedQualityKey {
        playlist = cachedPlaylist
      } else {
        playlist = try loadPlaylist(url: url, selectedQuality: selectedQuality)
        self.playlist = playlist
        playlistQualityKey = selectedQualityKey
      }
      guard isCurrent(taskGeneration) else {
        return
      }
      guard !playlist.segments.isEmpty, playlist.durationMs > 0 else {
        sendCacheError(
          NSError(
            domain: "player_m3u8",
            code: -4,
            userInfo: [NSLocalizedDescriptionKey: "No cacheable HLS segments found."]
          ),
          generation: taskGeneration
        )
        notifyFinished(generation: taskGeneration)
        return
      }

      let startIndex = playlist.segmentIndex(for: startPositionMs)
      let orderedSegments = Array(playlist.segments[startIndex...])
        + Array(playlist.segments[..<startIndex])
      let diskCacheStartMs = playlist.segments[startIndex].startTimeMs
      var diskCachePositionMs = diskCacheStartMs
      sendDiskCacheProgress(
        diskCacheStartMs: diskCacheStartMs,
        diskCachePositionMs: diskCachePositionMs,
        durationMs: playlist.durationMs,
        isComplete: false,
        generation: taskGeneration,
        quality: playlist.quality
      )

      for resource in playlist.resources {
        if !isCurrent(taskGeneration) { return }
        try? cacheUrl(resource, generation: taskGeneration)
      }

      for segment in orderedSegments {
        if !isCurrent(taskGeneration) { return }
        try cacheUrl(segment.url, generation: taskGeneration)
        if segment.startTimeMs >= diskCacheStartMs {
          diskCachePositionMs = min(segment.endTimeMs, playlist.durationMs)
          sendDiskCacheProgress(
            diskCacheStartMs: diskCacheStartMs,
            diskCachePositionMs: diskCachePositionMs,
            durationMs: playlist.durationMs,
            isComplete: false,
            generation: taskGeneration,
            quality: playlist.quality
          )
        }
      }

      if let audioUrl = audioUrl, isCurrent(taskGeneration) {
        cacheAudioSegments(audioUrl: audioUrl, generation: taskGeneration)
      }

      if isCurrent(taskGeneration) {
        sendDiskCacheProgress(
          diskCacheStartMs: 0,
          diskCachePositionMs: playlist.durationMs,
          durationMs: playlist.durationMs,
          isComplete: true,
          generation: taskGeneration,
          quality: playlist.quality
        )
        notifyFinished(generation: taskGeneration)
      }
    } catch {
      sendCacheError(error, generation: taskGeneration)
      notifyFinished(generation: taskGeneration)
      // Disk prefetch is best-effort and should not fail playback.
    }
  }

  private func cacheAudioSegments(audioUrl: URL, generation taskGeneration: Int) {
    let useHeaders = audioHeaders ?? headers
    do {
      let playlist = try loadPlaylist(
        url: audioUrl,
        selectedQuality: autoQuality(),
        headers: useHeaders
      )
      for resource in playlist.resources {
        if !isCurrent(taskGeneration) { return }
        try? cacheUrl(resource, generation: taskGeneration)
      }
      for segment in playlist.segments {
        if !isCurrent(taskGeneration) { return }
        try cacheUrl(segment.url, generation: taskGeneration)
      }
    } catch {
      // Audio prefetch is optional; playback should continue.
    }
  }

  private func loadPlaylist(
    url playlistUrl: URL,
    selectedQuality: [String: Any],
    depth: Int = 0,
    headers: [String: String]? = nil
  ) throws -> Playlist {
    guard !isCancelled, depth <= 3 else {
      return Playlist(segments: [], resources: [], durationMs: 0, quality: selectedQuality)
    }

    let useHeaders = headers ?? self.headers
    let data = try cacheManager.data(
      for: playlistUrl,
      headers: useHeaders,
      taskObserver: { [weak self] task in self?.setCurrentTask(task) },
      isCancelled: { [weak self] in self?.isCancelled ?? true }
    )
    guard let text = String(data: data, encoding: .utf8) else {
      return Playlist(segments: [], resources: [], durationMs: 0, quality: selectedQuality)
    }

    var segments: [Segment] = []
    var resources: [URL] = []
    var childPlaylists: [Variant] = []
    var pendingDurationMs: Int64?
    var pendingStartTimeMs: Int64 = 0
    var pendingVariantQuality: [String: Any]?

    for rawLine in text.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if line.hasPrefix("#EXTINF:") {
        pendingDurationMs = parseExtInfDurationMs(line)
      } else if line.hasPrefix("#EXT-X-STREAM-INF:") {
        pendingVariantQuality = parseStreamInfQuality(line)
      } else if line.hasPrefix("#EXT-X-KEY:") || line.hasPrefix("#EXT-X-MAP:") {
        if let resource = parseAttributeUri(line),
          let resourceUrl = URL(string: resource, relativeTo: playlistUrl)?.absoluteURL
        {
          resources.append(resourceUrl)
        }
      } else if line.hasPrefix("#") {
        continue
      } else if let durationMs = pendingDurationMs {
        if let segmentUrl = URL(string: line, relativeTo: playlistUrl)?.absoluteURL {
          let startTimeMs = pendingStartTimeMs
          let endTimeMs = startTimeMs + durationMs
          segments.append(
            Segment(
              index: segments.count,
              url: segmentUrl,
              startTimeMs: startTimeMs,
              endTimeMs: endTimeMs
            )
          )
          pendingStartTimeMs = endTimeMs
        }
        pendingDurationMs = nil
      } else if let childPlaylist = URL(string: line, relativeTo: playlistUrl)?.absoluteURL {
        childPlaylists.append(
          Variant(
            url: childPlaylist,
            quality: pendingVariantQuality ?? Self.autoQuality()
          )
        )
        pendingVariantQuality = nil
      }
    }

    if !segments.isEmpty {
      return Playlist(
        segments: segments,
        resources: resources,
        durationMs: segments.last?.endTimeMs ?? 0,
        quality: selectedQuality
      )
    }

    for childPlaylist in orderedVariants(childPlaylists, selectedQuality: selectedQuality) {
      let playlist = try loadPlaylist(
        url: childPlaylist.url,
        selectedQuality: childPlaylist.quality,
        depth: depth + 1
      )
      if !playlist.segments.isEmpty {
        return playlist
      }
    }

    return Playlist(segments: [], resources: [], durationMs: 0, quality: selectedQuality)
  }

  private func cacheUrl(_ url: URL, generation taskGeneration: Int) throws {
    try cacheManager.ensureCached(
      url: url,
      headers: headers,
      taskObserver: { [weak self] task in self?.setCurrentTask(task) },
      isCancelled: { [weak self] in
        guard let self else { return true }
        return !self.isCurrent(taskGeneration)
      }
    )
  }

  private func parseExtInfDurationMs(_ line: String) -> Int64 {
    let text = line
      .split(separator: ":", maxSplits: 1)
      .last?
      .split(separator: ",", maxSplits: 1)
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let seconds = Double(text ?? "") ?? 0
    return max(Int64((seconds * 1000).rounded()), 0)
  }

  private func parseAttributeUri(_ line: String) -> String? {
    let pattern = #"URI="([^"]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard let match = regex.firstMatch(in: line, range: range),
      let uriRange = Range(match.range(at: 1), in: line)
    else { return nil }
    return String(line[uriRange])
  }

  private func sendDiskCacheProgress(
    diskCacheStartMs: Int64,
    diskCachePositionMs: Int64,
    durationMs: Int64,
    isComplete: Bool,
    generation taskGeneration: Int,
    quality: [String: Any]
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isCurrent(taskGeneration) else { return }
      let playerId = self.playerIdProvider()
      guard self.taskId != nil || playerId >= 0 else { return }
      let percent = durationMs <= 0
        ? 0.0
        : min(max(Double(diskCachePositionMs) / Double(durationMs) * 100.0, 0), 100)
      let eventName: String
      if self.taskId == nil {
        eventName = "diskCache"
      } else if isComplete {
        eventName = "completed"
      } else {
        eventName = "progress"
      }
      var event: [String: Any] = [
        "playerId": playerId,
        "event": eventName,
        "url": self.url.absoluteString,
        "duration": durationMs,
        "diskCacheStartPosition": diskCacheStartMs,
        "diskCachePosition": diskCachePositionMs,
        "diskCachePercent": percent,
        "isDiskCacheComplete": isComplete,
        "quality": quality,
      ]
      if let taskId = self.taskId {
        event["taskId"] = taskId
      }
      self.eventSinkProvider()?(event)
    }
  }

  private func sendCacheError(_ error: Error, generation taskGeneration: Int) {
    guard let taskId else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isCurrent(taskGeneration) else { return }
      self.eventSinkProvider()?([
        "taskId": taskId,
        "url": self.url.absoluteString,
        "event": "error",
        "error": [
          "code": "cache_error",
          "message": error.localizedDescription,
        ],
      ])
    }
  }

  private func notifyFinished(generation taskGeneration: Int) {
    guard let onFinished else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.lock.lock()
      let shouldNotify = self.generation == taskGeneration
      self.lock.unlock()
      if shouldNotify {
        onFinished()
      }
    }
  }

  private var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }

  private func isCurrent(_ taskGeneration: Int) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return !cancelled && generation == taskGeneration
  }

  private func setCurrentTask(_ task: URLSessionTask?) {
    lock.lock()
    currentTask = task
    lock.unlock()
  }

  private func parseStreamInfQuality(_ line: String) -> [String: Any] {
    let resolution = parseAttribute(line, name: "RESOLUTION")
    let parts = resolution?.split(separator: "x")
    let width = Int(parts?.first ?? "") ?? 0
    let height = Int(parts?.last ?? "") ?? 0
    let bitrate = Int(parseAttribute(line, name: "BANDWIDTH") ?? "") ?? 0
    return Self.qualityPayload(width: width, height: height, bitrate: bitrate)
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

  private func orderedVariants(
    _ variants: [Variant],
    selectedQuality: [String: Any]
  ) -> [Variant] {
    guard !(selectedQuality["isAuto"] as? Bool ?? false) else {
      return variants
    }
    return variants.sorted { lhs, rhs in
      qualityDistance(lhs.quality, selectedQuality: selectedQuality) <
        qualityDistance(rhs.quality, selectedQuality: selectedQuality)
    }
  }

  private func qualityDistance(_ quality: [String: Any], selectedQuality: [String: Any]) -> Int {
    let selectedHeight = selectedQuality["height"] as? Int ?? 0
    let selectedBitrate = selectedQuality["bitrate"] as? Int ?? 0
    let selectedWidth = selectedQuality["width"] as? Int ?? 0
    let height = quality["height"] as? Int ?? 0
    let bitrate = quality["bitrate"] as? Int ?? 0
    let width = quality["width"] as? Int ?? 0
    let heightDistance = selectedHeight > 0 && height > 0 ? abs(height - selectedHeight) : 1_000_000
    let bitrateDistance = selectedBitrate > 0 && bitrate > 0
      ? abs(bitrate - selectedBitrate) / 1000
      : 1_000_000
    let widthDistance = selectedWidth > 0 && width > 0 ? abs(width - selectedWidth) : 1_000_000
    return heightDistance * 10_000 + bitrateDistance + widthDistance
  }

  private func normalizeQuality(_ quality: [String: Any]) -> [String: Any] {
    if quality["isAuto"] as? Bool ?? false {
      return Self.autoQuality()
    }
    return Self.qualityPayload(
      width: quality["width"] as? Int ?? 0,
      height: quality["height"] as? Int ?? 0,
      bitrate: quality["bitrate"] as? Int ?? 0
    )
  }

  private func qualityKey(_ quality: [String: Any]) -> String {
    [
      String(quality["isAuto"] as? Bool ?? false),
      String(quality["width"] as? Int ?? 0),
      String(quality["height"] as? Int ?? 0),
      String(quality["bitrate"] as? Int ?? 0),
    ].joined(separator: ":")
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

  private static func qualityPayload(width: Int, height: Int, bitrate: Int) -> [String: Any] {
    let safeHeight = max(height, 0)
    let safeBitrate = max(bitrate, 0)
    let label: String
    let id: String
    if safeHeight > 0 {
      label = "\(safeHeight)p"
      id = "\(safeHeight)p"
    } else if safeBitrate > 0 {
      label = "\(safeBitrate / 1000) Kbps"
      id = "\(safeBitrate)bps"
    } else {
      label = "Unknown"
      id = "unknown"
    }
    return [
      "id": id,
      "label": label,
      "width": max(width, 0),
      "height": safeHeight,
      "bitrate": safeBitrate,
      "isAuto": false,
    ]
  }

  private struct Variant {
    let url: URL
    let quality: [String: Any]
  }

  private struct Playlist {
    let segments: [Segment]
    let resources: [URL]
    let durationMs: Int64
    let quality: [String: Any]

    func segmentIndex(for positionMs: Int64) -> Int {
      guard !segments.isEmpty else { return 0 }
      let normalizedPositionMs = min(max(positionMs, 0), durationMs)
      return segments.firstIndex { normalizedPositionMs < $0.endTimeMs }
        ?? segments.index(before: segments.endIndex)
    }
  }

  private struct Segment {
    let index: Int
    let url: URL
    let startTimeMs: Int64
    let endTimeMs: Int64
  }
}
