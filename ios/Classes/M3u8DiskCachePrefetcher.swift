import Flutter
import Foundation

final class M3u8DiskCachePrefetcher {
  private let url: URL
  private let headers: [String: String]
  private let playerIdProvider: () -> Int64
  private let eventSinkProvider: () -> FlutterEventSink?
  private let cacheManager: M3u8IosCacheManager
  private let queue = DispatchQueue(label: "player_m3u8_disk_cache")
  private let lock = NSLock()
  private var cancelled = false
  private var generation = 0
  private var currentTask: URLSessionTask?
  private var playlist: Playlist?

  init(
    url: URL,
    headers: [String: String],
    playerIdProvider: @escaping () -> Int64,
    eventSinkProvider: @escaping () -> FlutterEventSink?,
    cacheManager: M3u8IosCacheManager = .shared
  ) {
    self.url = url
    self.headers = headers
    self.playerIdProvider = playerIdProvider
    self.eventSinkProvider = eventSinkProvider
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
      let playlist = try self.playlist ?? loadPlaylist(url: url)
      self.playlist = playlist
      guard !playlist.segments.isEmpty, playlist.durationMs > 0, isCurrent(taskGeneration) else {
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
        generation: taskGeneration
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
            generation: taskGeneration
          )
        }
      }

      if isCurrent(taskGeneration) {
        sendDiskCacheProgress(
          diskCacheStartMs: 0,
          diskCachePositionMs: playlist.durationMs,
          durationMs: playlist.durationMs,
          isComplete: true,
          generation: taskGeneration
        )
      }
    } catch {
      // Disk prefetch is best-effort and should not fail playback.
    }
  }

  private func loadPlaylist(url playlistUrl: URL, depth: Int = 0) throws -> Playlist {
    guard !isCancelled, depth <= 3 else {
      return Playlist(segments: [], resources: [], durationMs: 0)
    }

    let data = try cacheManager.data(
      for: playlistUrl,
      headers: headers,
      taskObserver: { [weak self] task in self?.setCurrentTask(task) },
      isCancelled: { [weak self] in self?.isCancelled ?? true }
    )
    guard let text = String(data: data, encoding: .utf8) else {
      return Playlist(segments: [], resources: [], durationMs: 0)
    }

    var segments: [Segment] = []
    var resources: [URL] = []
    var childPlaylists: [URL] = []
    var pendingDurationMs: Int64?
    var pendingStartTimeMs: Int64 = 0

    for rawLine in text.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if line.hasPrefix("#EXTINF:") {
        pendingDurationMs = parseExtInfDurationMs(line)
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
        childPlaylists.append(childPlaylist)
      }
    }

    if !segments.isEmpty {
      return Playlist(
        segments: segments,
        resources: resources,
        durationMs: segments.last?.endTimeMs ?? 0
      )
    }

    for childPlaylist in childPlaylists {
      let playlist = try loadPlaylist(url: childPlaylist, depth: depth + 1)
      if !playlist.segments.isEmpty {
        return playlist
      }
    }

    return Playlist(segments: [], resources: [], durationMs: 0)
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
    generation taskGeneration: Int
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isCurrent(taskGeneration) else { return }
      let playerId = self.playerIdProvider()
      guard playerId >= 0 else { return }
      let percent = durationMs <= 0
        ? 0.0
        : min(max(Double(diskCachePositionMs) / Double(durationMs) * 100.0, 0), 100)
      self.eventSinkProvider()?([
        "playerId": playerId,
        "event": "diskCache",
        "duration": durationMs,
        "diskCacheStartPosition": diskCacheStartMs,
        "diskCachePosition": diskCachePositionMs,
        "diskCachePercent": percent,
        "isDiskCacheComplete": isComplete,
      ])
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

  private struct Playlist {
    let segments: [Segment]
    let resources: [URL]
    let durationMs: Int64

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
