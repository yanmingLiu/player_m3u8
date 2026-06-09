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
  private var currentTask: URLSessionTask?

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
    queue.async { [weak self] in
      self?.cacheVod()
    }
  }

  func cancel() {
    lock.lock()
    cancelled = true
    let task = currentTask
    lock.unlock()
    task?.cancel()
    session.invalidateAndCancel()
  }

  private func cacheVod() {
    do {
      let playlist = try loadPlaylist(url: url)
      guard !playlist.segments.isEmpty, playlist.durationMs > 0 else { return }

      let directory = try cacheDirectory(for: url)
      var diskCachePositionMs: Int64 = 0
      sendDiskCacheProgress(
        diskCachePositionMs: diskCachePositionMs,
        durationMs: playlist.durationMs,
        isComplete: false
      )

      for resource in playlist.resources {
        if isCancelled { return }
        let destination = directory.appendingPathComponent(
          "resource_\(cacheKey(for: resource.absoluteString)).cache"
        )
        if !FileManager.default.fileExists(atPath: destination.path) {
          try? downloadFile(from: resource, to: destination)
        }
      }

      for (index, segment) in playlist.segments.enumerated() {
        if isCancelled { return }
        let destination = directory.appendingPathComponent("segment_\(index).cache")
        if !FileManager.default.fileExists(atPath: destination.path) {
          try downloadFile(from: segment.url, to: destination)
        }
        diskCachePositionMs = min(diskCachePositionMs + segment.durationMs, playlist.durationMs)
        sendDiskCacheProgress(
          diskCachePositionMs: diskCachePositionMs,
          durationMs: playlist.durationMs,
          isComplete: false
        )
      }

      if !isCancelled {
        sendDiskCacheProgress(
          diskCachePositionMs: playlist.durationMs,
          durationMs: playlist.durationMs,
          isComplete: true
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
          segments.append(Segment(url: segmentUrl, durationMs: durationMs))
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
        durationMs: segments.reduce(0) { $0 + $1.durationMs }
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
    diskCachePositionMs: Int64,
    durationMs: Int64,
    isComplete: Bool
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.isCancelled else { return }
      let playerId = self.playerIdProvider()
      guard playerId >= 0 else { return }
      self.eventSinkProvider()?([
        "playerId": playerId,
        "event": "diskCache",
        "duration": durationMs,
        "diskCachePosition": diskCachePositionMs,
        "isDiskCacheComplete": isComplete,
      ])
    }
  }

  private var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
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
  }

  private struct Segment {
    let url: URL
    let durationMs: Int64
  }
}
