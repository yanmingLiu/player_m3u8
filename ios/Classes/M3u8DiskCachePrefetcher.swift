import Flutter
import Foundation
import CryptoKit

final class M3u8DiskCachePrefetcher {
  private let url: URL
  private let headers: [String: String]
  private let playerIdProvider: () -> Int64
  private let eventSinkProvider: () -> FlutterEventSink?
  private let queue = DispatchQueue(label: "player_m3u8_disk_cache")
  private let session = URLSession(configuration: .ephemeral)
  private let lock = NSLock()
  private var cancelled = false
  private var generation = 0
  private var currentTask: URLSessionTask?
  private var playlist: Playlist?

  init(
    url: URL,
    headers: [String: String],
    playerIdProvider: @escaping () -> Int64,
    eventSinkProvider: @escaping () -> FlutterEventSink?
  ) {
    self.url = url
    self.headers = headers
    self.playerIdProvider = playerIdProvider
    self.eventSinkProvider = eventSinkProvider
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
    session.invalidateAndCancel()
  }

  private func cacheVod(startPositionMs: Int64, generation taskGeneration: Int) {
    do {
      let playlist = try self.playlist ?? loadPlaylist(url: url)
      self.playlist = playlist
      guard !playlist.segments.isEmpty, playlist.durationMs > 0, isCurrent(taskGeneration) else {
        return
      }

      let directory = try cacheDirectory(for: url)
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
        let destination = directory.appendingPathComponent(
          "resource_\(cacheKey(for: resource.absoluteString)).cache"
        )
        if !FileManager.default.fileExists(atPath: destination.path) {
          try? downloadFile(from: resource, to: destination)
        }
      }

      for segment in orderedSegments {
        if !isCurrent(taskGeneration) { return }
        let destination = directory.appendingPathComponent(
          "segment_\(segment.index)_\(cacheKey(for: segment.url.absoluteString)).cache"
        )
        if !FileManager.default.fileExists(atPath: destination.path) {
          try downloadFile(from: segment.url, to: destination)
        }
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

    let data = try requestData(from: playlistUrl)
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

  private func requestData(from requestUrl: URL) throws -> Data {
    var request = URLRequest(url: requestUrl)
    headers.forEach { key, value in
      request.setValue(value, forHTTPHeaderField: key)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Data, Error>?
    let task = session.dataTask(with: request) { data, _, error in
      if let error {
        result = .failure(error)
      } else {
        result = .success(data ?? Data())
      }
      semaphore.signal()
    }
    setCurrentTask(task)
    task.resume()
    semaphore.wait()
    setCurrentTask(nil)
    return try result?.get() ?? Data()
  }

  private func downloadFile(from requestUrl: URL, to destination: URL) throws {
    var request = URLRequest(url: requestUrl)
    headers.forEach { key, value in
      request.setValue(value, forHTTPHeaderField: key)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<URL, Error>?
    let task = session.downloadTask(with: request) { temporaryUrl, _, error in
      if let error {
        result = .failure(error)
      } else if let temporaryUrl {
        result = .success(temporaryUrl)
      } else {
        result = .failure(NSError(domain: "player_m3u8", code: -1))
      }
      semaphore.signal()
    }
    setCurrentTask(task)
    task.resume()
    semaphore.wait()
    setCurrentTask(nil)

    let temporaryUrl = try result?.get()
    guard let temporaryUrl else { return }

    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: temporaryUrl, to: destination)
  }

  private func cacheDirectory(for playlistUrl: URL) throws -> URL {
    let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("player_m3u8_media_cache", isDirectory: true)
      .appendingPathComponent(cacheKey(for: playlistUrl.absoluteString), isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func cacheKey(for value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
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
