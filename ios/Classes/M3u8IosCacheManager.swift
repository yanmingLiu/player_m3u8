import CryptoKit
import Foundation

final class M3u8IosCacheManager {
  static let shared = M3u8IosCacheManager()

  private let lock = NSLock()
  private var maxCacheBytes: Int64 = 512 * 1024 * 1024

  private init() {}

  func configure(maxSizeBytes: Int64) throws {
    guard maxSizeBytes > 0 else {
      throw NSError(
        domain: "player_m3u8",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "maxSizeBytes must be greater than zero."]
      )
    }
    lock.lock()
    maxCacheBytes = maxSizeBytes
    lock.unlock()
    try trimIfNeeded()
  }

  func clear() throws {
    lock.lock()
    defer { lock.unlock() }
    let directory = try cacheDirectory(create: false)
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }

  func info() throws -> [String: Int64] {
    lock.lock()
    let configuredMaxCacheBytes = maxCacheBytes
    lock.unlock()
    let directory = try cacheDirectory(create: false)
    return [
      "maxSizeBytes": configuredMaxCacheBytes,
      "sizeBytes": try directorySize(directory),
    ]
  }

  func data(
    for url: URL,
    headers: [String: String],
    taskObserver: ((URLSessionTask?) -> Void)? = nil,
    isCancelled: () -> Bool = { false }
  ) throws -> Data {
    let fileUrl = try ensureCached(
      url: url,
      headers: headers,
      taskObserver: taskObserver,
      isCancelled: isCancelled
    )
    lock.lock()
    defer { lock.unlock() }
    touchLocked(fileUrl)
    return try Data(contentsOf: fileUrl)
  }

  @discardableResult
  func ensureCached(
    url: URL,
    headers: [String: String],
    taskObserver: ((URLSessionTask?) -> Void)? = nil,
    isCancelled: () -> Bool = { false }
  ) throws -> URL {
    if isCancelled() {
      throw CancellationError()
    }
    let fileUrl = try cacheFile(for: url, headers: headers)
    lock.lock()
    let exists = FileManager.default.fileExists(atPath: fileUrl.path)
    lock.unlock()
    if exists {
      touch(fileUrl)
      return fileUrl
    }

    let downloadedUrl = try download(
      url: url,
      headers: headers,
      taskObserver: taskObserver,
      isCancelled: isCancelled
    )
    if isCancelled() {
      try? FileManager.default.removeItem(at: downloadedUrl)
      throw CancellationError()
    }
    lock.lock()
    defer { lock.unlock() }
    if FileManager.default.fileExists(atPath: fileUrl.path) {
      try? FileManager.default.removeItem(at: downloadedUrl)
      touchLocked(fileUrl)
      return fileUrl
    }
    try FileManager.default.createDirectory(
      at: fileUrl.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.moveItem(at: downloadedUrl, to: fileUrl)
    touchLocked(fileUrl)
    try trimIfNeededLocked()
    return fileUrl
  }

  private func download(
    url: URL,
    headers: [String: String],
    taskObserver: ((URLSessionTask?) -> Void)?,
    isCancelled: () -> Bool
  ) throws -> URL {
    if isCancelled() {
      throw CancellationError()
    }
    var request = URLRequest(url: url)
    headers.forEach { key, value in
      request.setValue(value, forHTTPHeaderField: key)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<URL, Error>?
    let session = URLSession(configuration: .ephemeral)
    let task = session.downloadTask(with: request) { temporaryUrl, _, error in
      if let error {
        result = .failure(error)
      } else if let temporaryUrl {
        let persistentTemporaryUrl = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
        do {
          try FileManager.default.moveItem(at: temporaryUrl, to: persistentTemporaryUrl)
          result = .success(persistentTemporaryUrl)
        } catch {
          result = .failure(error)
        }
      } else {
        result = .failure(NSError(domain: "player_m3u8", code: -2))
      }
      semaphore.signal()
    }
    taskObserver?(task)
    task.resume()
    semaphore.wait()
    taskObserver?(nil)
    session.invalidateAndCancel()
    if isCancelled() {
      throw CancellationError()
    }
    return try result?.get() ?? {
      throw NSError(domain: "player_m3u8", code: -3)
    }()
  }

  private func cacheFile(for url: URL, headers: [String: String]) throws -> URL {
    try cacheDirectory(create: true)
      .appendingPathComponent(cacheKey(for: cacheIdentity(url: url, headers: headers)))
      .appendingPathExtension("cache")
  }

  private func cacheDirectory(create: Bool) throws -> URL {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("player_m3u8_media_cache", isDirectory: true)
    if create {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return directory
  }

  private func cacheKey(for value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  private func cacheIdentity(url: URL, headers: [String: String]) -> String {
    let headerIdentity = headers
      .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
      .map { "\($0.key.lowercased())=\($0.value)" }
      .joined(separator: "\n")
    return "\(url.absoluteString)\n\(headerIdentity)"
  }

  private func touch(_ url: URL) {
    lock.lock()
    touchLocked(url)
    lock.unlock()
  }

  private func touchLocked(_ url: URL) {
    try? FileManager.default.setAttributes(
      [.modificationDate: Date()],
      ofItemAtPath: url.path
    )
  }

  private func trimIfNeeded() throws {
    lock.lock()
    defer { lock.unlock() }
    try trimIfNeededLocked()
  }

  private func trimIfNeededLocked() throws {
    let directory = try cacheDirectory(create: false)
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    let files = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    )
    var entries: [(url: URL, size: Int64, date: Date)] = []
    var totalSize: Int64 = 0

    for file in files {
      let values = try file.resourceValues(forKeys: [
        .contentModificationDateKey,
        .fileSizeKey,
      ])
      let size = Int64(values.fileSize ?? 0)
      totalSize += size
      entries.append((file, size, values.contentModificationDate ?? .distantPast))
    }

    guard totalSize > maxCacheBytes else { return }
    for entry in entries.sorted(by: { $0.date < $1.date }) {
      try? FileManager.default.removeItem(at: entry.url)
      totalSize -= entry.size
      if totalSize <= maxCacheBytes {
        break
      }
    }
  }

  private func directorySize(_ directory: URL) throws -> Int64 {
    guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return 0
    }

    var totalSize: Int64 = 0
    for case let fileUrl as URL in enumerator {
      let values = try fileUrl.resourceValues(forKeys: [
        .isRegularFileKey,
        .fileSizeKey,
      ])
      guard values.isRegularFile == true else { continue }
      totalSize += Int64(values.fileSize ?? 0)
    }
    return totalSize
  }
}
