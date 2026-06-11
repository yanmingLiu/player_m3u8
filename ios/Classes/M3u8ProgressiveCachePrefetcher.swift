import Flutter
import Foundation

final class M3u8ProgressiveCachePrefetcher {
  let taskId: String
  let priority: Int

  private let url: URL
  private let headers: [String: String]
  private let cacheKey: String?
  private let maxRetries: Int
  private let metadata: [String: Any]
  private let eventSinkProvider: () -> FlutterEventSink?
  private let onFinished: (() -> Void)?
  private let cacheManager: M3u8IosCacheManager
  private let queue = DispatchQueue(label: "player_m3u8_progressive_cache")
  private let lock = NSLock()

  private var status = "queued"
  private var cancelled = false
  private var currentTask: URLSessionTask?
  private var bytesCached: Int64 = 0
  private var bytesTotal: Int64 = 0
  private var downloadSpeedBytesPerSecond: Int64 = 0
  private var cacheHitCount = 0
  private var networkFetchCount = 0
  private var retryCount = 0
  private var lastBytesSample: Int64 = 0
  private var lastBytesSampleAt = Date()

  init(
    url: URL,
    headers: [String: String],
    cacheKey: String?,
    taskId: String,
    priority: Int,
    maxRetries: Int,
    metadata: [String: Any],
    eventSinkProvider: @escaping () -> FlutterEventSink?,
    onFinished: (() -> Void)?,
    cacheManager: M3u8IosCacheManager = .shared
  ) {
    self.url = url
    self.headers = headers
    self.cacheKey = cacheKey
    self.taskId = taskId
    self.priority = priority
    self.maxRetries = maxRetries
    self.metadata = metadata
    self.eventSinkProvider = eventSinkProvider
    self.onFinished = onFinished
    self.cacheManager = cacheManager
  }

  var isRunning: Bool { isRunningLocked }
  var isQueued: Bool {
    lock.lock()
    defer { lock.unlock() }
    return status == "queued"
  }

  func markQueued() {
    lock.lock()
    let shouldUpdate = !cancelled
    if shouldUpdate {
      status = "queued"
    }
    lock.unlock()
    guard shouldUpdate else { return }
    sendEvent("progress")
  }

  func start() {
    lock.lock()
    let shouldStart = !cancelled && status == "queued"
    if shouldStart {
      status = "running"
    }
    lock.unlock()
    guard shouldStart else { return }
    sendEvent("progress")
    queue.async { [weak self] in self?.cache() }
  }

  func pause() {
    lock.lock()
    status = "paused"
    let task = currentTask
    lock.unlock()
    task?.cancel()
    sendEvent("progress")
  }

  func resume() {
    markQueued()
  }

  func cancel() {
    lock.lock()
    cancelled = true
    status = "cancelled"
    let task = currentTask
    lock.unlock()
    task?.cancel()
    sendEvent("cancelled")
  }

  func snapshot() -> [String: Any] {
    [
      "playerId": -1,
      "event": status == "completed" ? "completed" : "progress",
      "taskId": taskId,
      "url": url.absoluteString,
      "owner": "standalone",
      "status": status,
      "sourceType": M3u8SourceType.progressive.platformValue,
      "priority": priority,
      "diskCachePercent": percent(),
      "isDiskCacheComplete": status == "completed",
      "bytesCached": bytesCached,
      "bytesTotal": bytesTotal,
      "downloadSpeedBytesPerSecond": downloadSpeedBytesPerSecond,
      "cacheHitCount": cacheHitCount,
      "networkFetchCount": networkFetchCount,
      "segmentIndex": 0,
      "segmentCount": 1,
      "currentUrl": url.absoluteString,
      "retryCount": retryCount,
      "updatedAt": Int64(Date().timeIntervalSince1970 * 1000),
      "metadata": metadata,
    ]
  }

  private func cache() {
    var attempt = 0
    while isRunning {
      do {
        if cacheManager.cachedFileIfExists(for: url, headers: headers, cacheKey: cacheKey) != nil {
          cacheHitCount += 1
        } else {
          networkFetchCount += 1
        }
        let file = try cacheManager.ensureCached(
          url: url,
          headers: headers,
          cacheKey: cacheKey,
          taskObserver: { [weak self] task in
            self?.lock.lock()
            self?.currentTask = task
            self?.lock.unlock()
          },
          isCancelled: { [weak self] in !(self?.isRunningLocked ?? false) }
        )
        bytesCached = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        bytesTotal = max(bytesTotal, bytesCached)
        status = "completed"
        sendEvent("completed")
        DispatchQueue.main.async { [weak self] in self?.onFinished?() }
        return
      } catch {
        if !isRunning { return }
        if attempt >= maxRetries {
          status = "error"
          sendEvent("error", error: error)
          DispatchQueue.main.async { [weak self] in self?.onFinished?() }
          return
        }
        attempt += 1
        retryCount = attempt
        Thread.sleep(forTimeInterval: min(Double(attempt) * 0.2, 1.0))
      }
    }
  }

  private func sendEvent(_ eventName: String, error: Error? = nil) {
    updateSpeed()
    var event = snapshot()
    event["event"] = eventName
    if let error {
      event["error"] = [
        "code": "cache_error",
        "message": error.localizedDescription,
      ]
    }
    DispatchQueue.main.async { [weak self] in
      self?.eventSinkProvider()?(event)
    }
  }

  private func percent() -> Double {
    guard bytesTotal > 0 else { return 0 }
    return min(max(Double(bytesCached) / Double(bytesTotal) * 100.0, 0), 100)
  }

  private func updateSpeed() {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastBytesSampleAt)
    guard elapsed >= 0.25 else { return }
    let delta = bytesCached - lastBytesSample
    downloadSpeedBytesPerSecond = max(Int64(Double(delta) / elapsed), 0)
    lastBytesSample = bytesCached
    lastBytesSampleAt = now
  }

  private var isRunningLocked: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !cancelled && status == "running"
  }
}
