import AVFoundation
import Flutter
import UIKit

public class PlayerM3u8Plugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var textureRegistry: FlutterTextureRegistry
  private var eventSink: FlutterEventSink?
  private var cacheEventSink: FlutterEventSink?
  private var players: [Int64: M3u8IosPlayer] = [:]
  private var cacheTasks: [String: CacheTaskBox] = [:]
  private var maxConcurrentPrecacheTasks = 2

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "player_m3u8/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "player_m3u8/events",
      binaryMessenger: registrar.messenger()
    )
    let cacheEventChannel = FlutterEventChannel(
      name: "player_m3u8/cache_events",
      binaryMessenger: registrar.messenger()
    )
    let instance = PlayerM3u8Plugin(textureRegistry: registrar.textures())
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    cacheEventChannel.setStreamHandler(CacheEventStreamHandler(plugin: instance))
  }

  init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create":
      create(call: call, result: result)
    case "play":
      withPlayer(call: call, result: result) { player in
        player.play()
        result(nil)
      }
    case "pause":
      withPlayer(call: call, result: result) { player in
        player.pause()
        result(nil)
      }
    case "seekTo":
      withPlayer(call: call, result: result) { player in
        guard
          let arguments = call.arguments as? [String: Any],
          let position = arguments["position"] as? NSNumber
        else {
          result(
            FlutterError(
              code: "invalid_position",
              message: "position is required.",
              details: nil
            )
          )
          return
        }
        player.seek(to: position.int64Value)
        result(nil)
      }
    case "setQuality":
      withPlayer(call: call, result: result) { player in
        guard
          let arguments = call.arguments as? [String: Any],
          let quality = arguments["quality"] as? [String: Any]
        else {
          result(
            FlutterError(
              code: "invalid_quality",
              message: "quality is required.",
              details: nil
            )
          )
          return
        }
        guard player.supportsQualitySelection else {
          result(
            FlutterError(
              code: "unsupported_source_type",
              message: "Quality selection is only supported for HLS sources.",
              details: nil
            )
          )
          return
        }
        player.setQuality(quality)
        result(nil)
      }
    case "setRecoveryPolicy":
      withPlayer(call: call, result: result) { player in
        let arguments = call.arguments as? [String: Any]
        let policy = arguments?["recoveryPolicy"] as? [String: Any]
        player.setRecoveryPolicy(M3u8RecoveryPolicy.from(policy))
        result(nil)
      }
    case "setPlaybackSpeed":
      withPlayer(call: call, result: result) { player in
        guard
          let arguments = call.arguments as? [String: Any],
          let speed = arguments["speed"] as? NSNumber,
          speed.doubleValue.isFinite,
          speed.doubleValue >= 0.25,
          speed.doubleValue <= 2.0
        else {
          result(
            FlutterError(
              code: "invalid_playback_speed",
              message: "speed must be finite and between 0.25 and 2.0.",
              details: nil
            )
          )
          return
        }
        player.setPlaybackSpeed(speed.doubleValue)
        result(nil)
      }
    case "setVolume":
      withPlayer(call: call, result: result) { player in
        guard
          let arguments = call.arguments as? [String: Any],
          let volume = arguments["volume"] as? NSNumber,
          volume.doubleValue.isFinite,
          volume.doubleValue >= 0,
          volume.doubleValue <= 1
        else {
          result(
            FlutterError(
              code: "invalid_volume",
              message: "volume must be finite and between 0.0 and 1.0.",
              details: nil
            )
          )
          return
        }
        player.setVolume(volume.doubleValue)
        result(nil)
      }
    case "setMuted":
      withPlayer(call: call, result: result) { player in
        guard
          let arguments = call.arguments as? [String: Any],
          let isMuted = arguments["isMuted"] as? Bool
        else {
          result(
            FlutterError(code: "invalid_muted", message: "isMuted is required.", details: nil)
          )
          return
        }
        player.setMuted(isMuted)
        result(nil)
      }
    case "getScreenBrightness":
      result(Double(UIScreen.main.brightness))
    case "setScreenBrightness":
      guard
        let arguments = call.arguments as? [String: Any],
        let brightness = arguments["brightness"] as? NSNumber,
        brightness.doubleValue.isFinite,
        brightness.doubleValue >= 0,
        brightness.doubleValue <= 1
      else {
        result(
          FlutterError(
            code: "invalid_brightness",
            message: "brightness must be finite and between 0.0 and 1.0.",
            details: nil
          )
        )
        return
      }
      UIScreen.main.brightness = CGFloat(brightness.doubleValue)
      result(nil)
    case "setSubtitle":
      withPlayer(call: call, result: result) { player in
        let arguments = call.arguments as? [String: Any]
        player.setSubtitle(arguments?["subtitleId"] as? String)
        result(nil)
      }
    case "setAudioTrack":
      withPlayer(call: call, result: result) { player in
        let arguments = call.arguments as? [String: Any]
        player.setAudioTrack(arguments?["audioTrackId"] as? String)
        result(nil)
      }
    case "dispose":
      guard
        let arguments = call.arguments as? [String: Any],
        let playerId = arguments["playerId"] as? NSNumber
      else {
        result(
          FlutterError(
            code: "invalid_player_id",
            message: "playerId is required.",
            details: nil
          )
        )
        return
      }
      let id = playerId.int64Value
      players.removeValue(forKey: id)?.dispose()
      textureRegistry.unregisterTexture(id)
      result(nil)
    case "configureCache":
      configureCache(call: call, result: result)
    case "clearCache":
      clearCache(result: result)
    case "getCacheInfo":
      getCacheInfo(result: result)
    case "sourceCacheInfo":
      sourceCacheInfo(call: call, result: result)
    case "clearSourceCache":
      clearSourceCache(call: call, result: result)
    case "cacheTasks":
      cacheTasks(result: result)
    case "precache":
      precache(call: call, result: result)
    case "cancelPrecache":
      cancelPrecache(call: call, result: result)
    case "pausePrecache":
      pausePrecache(call: call, result: result)
    case "resumePrecache":
      resumePrecache(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func create(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let videoUrlString = arguments["videoUrl"] as? String,
      let videoUrl = URL(string: videoUrlString)
    else {
      result(FlutterError(code: "invalid_url", message: "videoUrl is required.", details: nil))
      return
    }
    var audioUrl: URL? = nil
    if let audioUrlString = arguments["audioUrl"] as? String {
      audioUrl = URL(string: audioUrlString)
    }
    let videoHeaders = arguments["videoHeaders"] as? [String: String] ?? [:]
    let audioHeaders = arguments["audioHeaders"] as? [String: String]
    let cacheKey = arguments["cacheKey"] as? String
    let initialPositionMs = (arguments["initialPosition"] as? NSNumber)?.int64Value ?? 0
    guard initialPositionMs >= 0 else {
      result(
        FlutterError(
          code: "invalid_initial_position",
          message: "initialPosition must be a non-negative integer.",
          details: nil
        )
      )
      return
    }
    guard
      let playbackSpeed = playbackSpeed(from: arguments["playbackSpeed"])
    else {
      result(
        FlutterError(
          code: "invalid_playback_speed",
          message: "playbackSpeed must be finite and between 0.25 and 2.0.",
          details: nil
        )
      )
      return
    }
    guard
      let volume = volume(from: arguments["volume"])
    else {
      result(
        FlutterError(
          code: "invalid_volume",
          message: "volume must be finite and between 0.0 and 1.0.",
          details: nil
        )
      )
      return
    }
    let player = M3u8IosPlayer(
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      videoHeaders: videoHeaders,
      audioHeaders: audioHeaders,
      cacheKey: cacheKey,
      sourceType: M3u8SourceType.from(arguments["sourceType"]),
      initialPositionMs: initialPositionMs,
      playbackSpeed: playbackSpeed,
      volume: volume,
      isMuted: arguments["isMuted"] as? Bool ?? false,
      externalSubtitles: arguments["subtitles"] as? [[String: Any]] ?? [],
      selectedSubtitleId: arguments["selectedSubtitleId"] as? String,
      selectedAudioTrackId: arguments["selectedAudioTrackId"] as? String,
      recoveryPolicy: M3u8RecoveryPolicy.from(arguments["recoveryPolicy"] as? [String: Any]),
      textureRegistry: textureRegistry,
      eventSinkProvider: { [weak self] in self?.eventSink }
    )
    let textureId = textureRegistry.register(player)
    player.textureId = textureId
    players[textureId] = player
    result(textureId)
  }

  private func playbackSpeed(from value: Any?) -> Double? {
    guard let value else {
      return 1.0
    }
    guard let speed = (value as? NSNumber)?.doubleValue,
      speed.isFinite,
      speed >= 0.25,
      speed <= 2.0
    else {
      return nil
    }
    return speed
  }

  private func volume(from value: Any?) -> Double? {
    guard let value else {
      return 1.0
    }
    guard let volume = (value as? NSNumber)?.doubleValue,
      volume.isFinite,
      volume >= 0,
      volume <= 1
    else {
      return nil
    }
    return volume
  }

  private func configureCache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let maxSizeBytes = arguments["maxSizeBytes"] as? NSNumber,
      maxSizeBytes.int64Value > 0
    else {
      result(
        FlutterError(
          code: "invalid_cache_size",
          message: "maxSizeBytes must be greater than zero.",
          details: nil
        )
      )
      return
    }
    let maxConcurrentPrecacheTasks =
      (arguments["maxConcurrentPrecacheTasks"] as? NSNumber)?.intValue ?? self.maxConcurrentPrecacheTasks
    guard maxConcurrentPrecacheTasks > 0 else {
      result(
        FlutterError(
          code: "invalid_cache_concurrency",
          message: "maxConcurrentPrecacheTasks must be greater than zero.",
          details: nil
        )
      )
      return
    }
    if maxSizeBytes.int64Value != M3u8IosCacheManager.shared.configuredMaxSizeBytes() {
      guard players.isEmpty else {
        result(
          FlutterError(
            code: "active_players",
            message: "Cache size cannot be configured while players are active.",
            details: nil
          )
        )
        return
      }
      guard cacheTasks.isEmpty else {
        result(
          FlutterError(
            code: "active_cache_tasks",
            message: "Cache size cannot be configured while cache tasks are active.",
            details: nil
          )
        )
        return
      }
    }
    do {
      self.maxConcurrentPrecacheTasks = Int(maxConcurrentPrecacheTasks)
      try M3u8IosCacheManager.shared.configure(maxSizeBytes: maxSizeBytes.int64Value)
      scheduleCacheTasks()
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "cache_config_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func clearCache(result: @escaping FlutterResult) {
    guard players.isEmpty else {
      result(
        FlutterError(
          code: "active_players",
          message: "Cache cannot be cleared while players are active.",
          details: nil
        )
      )
      return
    }
    guard cacheTasks.isEmpty else {
      result(
        FlutterError(
          code: "active_cache_tasks",
          message: "Cache cannot be cleared while cache tasks are active.",
          details: nil
        )
      )
      return
    }
    do {
      try M3u8IosCacheManager.shared.clear()
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "cache_clear_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func getCacheInfo(result: @escaping FlutterResult) {
    do {
      result(try M3u8IosCacheManager.shared.info())
    } catch {
      result(
        FlutterError(
          code: "cache_info_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func sourceCacheInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let videoUrlString = arguments["videoUrl"] as? String,
      let videoUrl = URL(string: videoUrlString)
    else {
      result(FlutterError(code: "invalid_url", message: "videoUrl is required.", details: nil))
      return
    }
    do {
      result(
        try M3u8IosCacheManager.shared.sourceInfo(
          url: videoUrl,
          headers: arguments["videoHeaders"] as? [String: String] ?? [:],
          cacheKey: arguments["cacheKey"] as? String
        )
      )
    } catch {
      result(FlutterError(code: "cache_info_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func clearSourceCache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard players.isEmpty else {
      result(
        FlutterError(
          code: "active_players",
          message: "Source cache cannot be cleared while players are active.",
          details: nil
        )
      )
      return
    }
    guard cacheTasks.isEmpty else {
      result(
        FlutterError(
          code: "active_cache_tasks",
          message: "Source cache cannot be cleared while cache tasks are active.",
          details: nil
        )
      )
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let videoUrlString = arguments["videoUrl"] as? String,
      let videoUrl = URL(string: videoUrlString)
    else {
      result(FlutterError(code: "invalid_url", message: "videoUrl is required.", details: nil))
      return
    }
    do {
      try M3u8IosCacheManager.shared.clearSource(
        url: videoUrl,
        headers: arguments["videoHeaders"] as? [String: String] ?? [:],
        cacheKey: arguments["cacheKey"] as? String
      )
      result(nil)
    } catch {
      result(FlutterError(code: "cache_clear_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func cacheTasks(result: @escaping FlutterResult) {
    result(cacheTasks.values.map { $0.snapshot() })
  }

  private func precache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let videoUrlString = arguments["videoUrl"] as? String,
      !videoUrlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let videoUrl = URL(string: videoUrlString)
    else {
      result(FlutterError(code: "invalid_url", message: "videoUrl is required.", details: nil))
      return
    }
    var audioUrl: URL? = nil
    if let audioUrlString = arguments["audioUrl"] as? String {
      audioUrl = URL(string: audioUrlString)
    }
    let initialPositionMs = (arguments["initialPosition"] as? NSNumber)?.int64Value ?? 0
    guard initialPositionMs >= 0 else {
      result(
        FlutterError(
          code: "invalid_initial_position",
          message: "initialPosition must be a non-negative integer.",
          details: nil
        )
      )
      return
    }
    let videoHeaders = arguments["videoHeaders"] as? [String: String] ?? [:]
    let audioHeaders = arguments["audioHeaders"] as? [String: String]
    let cacheKey = arguments["cacheKey"] as? String
    let sourceType = M3u8SourceType.from(arguments["sourceType"]).resolve(url: videoUrl)
    let priority = (arguments["priority"] as? NSNumber)?.intValue ?? 0
    let maxRetries = (arguments["maxRetries"] as? NSNumber)?.intValue ?? 2
    guard maxRetries >= 0 else {
      result(FlutterError(code: "invalid_max_retries", message: "maxRetries must be non-negative.", details: nil))
      return
    }
    let metadata = arguments["metadata"] as? [String: Any] ?? [:]
    let quality = arguments["quality"] as? [String: Any] ?? autoQuality()
    let taskId = UUID().uuidString
    let task: CacheTaskBox
    if sourceType == .hls {
      let prefetcher = M3u8DiskCachePrefetcher(
        url: videoUrl,
        headers: videoHeaders,
        cacheKey: cacheKey,
        playerIdProvider: { -1 },
        eventSinkProvider: { [weak self] in self?.cacheEventSink },
        taskId: taskId,
        owner: "standalone",
        sourceType: sourceType,
        priority: Int(priority),
        maxRetries: Int(maxRetries),
        metadata: metadata,
        onFinished: { [weak self] in
          self?.cacheTasks.removeValue(forKey: taskId)
          self?.scheduleCacheTasks()
        },
        qualityProvider: { quality },
        audioUrl: audioUrl,
        audioHeaders: audioHeaders
      )
      task = CacheTaskBox(
        taskId: taskId,
        priority: Int(priority),
        markQueued: { positionMs in prefetcher.markQueued(positionMs: positionMs) },
        start: { prefetcher.start() },
        pause: { prefetcher.pause() },
        cancel: { prefetcher.cancel() },
        snapshot: { prefetcher.snapshot() }
      )
    } else {
      let prefetcher = M3u8ProgressiveCachePrefetcher(
        url: videoUrl,
        headers: videoHeaders,
        cacheKey: cacheKey,
        taskId: taskId,
        priority: Int(priority),
        maxRetries: Int(maxRetries),
        metadata: metadata,
        eventSinkProvider: { [weak self] in self?.cacheEventSink },
        onFinished: { [weak self] in
          self?.cacheTasks.removeValue(forKey: taskId)
          self?.scheduleCacheTasks()
        }
      )
      task = CacheTaskBox(
        taskId: taskId,
        priority: Int(priority),
        markQueued: { _ in prefetcher.markQueued() },
        start: { prefetcher.start() },
        pause: { prefetcher.pause() },
        cancel: { prefetcher.cancel() },
        snapshot: { prefetcher.snapshot() }
      )
    }
    cacheTasks[taskId] = task
    task.markQueued(positionMs: initialPositionMs)
    scheduleCacheTasks()
    result(taskId)
  }

  private func cancelPrecache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let taskId = arguments["taskId"] as? String,
      !taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "invalid_cache_task", message: "taskId is required.", details: nil))
      return
    }
    cacheTasks.removeValue(forKey: taskId)?.cancelTask()
    scheduleCacheTasks()
    result(nil)
  }

  private func pausePrecache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let taskId = arguments["taskId"] as? String,
      !taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "invalid_cache_task", message: "taskId is required.", details: nil))
      return
    }
    guard let task = cacheTasks[taskId] else {
      result(FlutterError(code: "unknown_cache_task", message: "No cache task exists for taskId \(taskId).", details: nil))
      return
    }
    task.pauseTask()
    scheduleCacheTasks()
    result(nil)
  }

  private func resumePrecache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let taskId = arguments["taskId"] as? String,
      !taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "invalid_cache_task", message: "taskId is required.", details: nil))
      return
    }
    guard let task = cacheTasks[taskId] else {
      result(FlutterError(code: "unknown_cache_task", message: "No cache task exists for taskId \(taskId).", details: nil))
      return
    }
    if task.isPaused {
      task.resumeTask()
    }
    scheduleCacheTasks()
    result(nil)
  }

  private func scheduleCacheTasks() {
    let running = cacheTasks.values.filter { $0.isRunning }.count
    let capacity = max(maxConcurrentPrecacheTasks - running, 0)
    guard capacity > 0 else { return }
    cacheTasks.values
      .filter { $0.isQueued }
      .sorted { $0.priority > $1.priority }
      .prefix(capacity)
      .forEach { $0.startTask() }
  }

  private func withPlayer(
    call: FlutterMethodCall,
    result: @escaping FlutterResult,
    action: (M3u8IosPlayer) -> Void
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let playerId = arguments["playerId"] as? NSNumber,
      let player = players[playerId.int64Value]
    else {
      result(
        FlutterError(
          code: "unknown_player",
          message: "No player exists for the supplied playerId.",
          details: nil
        )
      )
      return
    }
    action(player)
  }

  private final class CacheEventStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: PlayerM3u8Plugin?

    init(plugin: PlayerM3u8Plugin) {
      self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
      -> FlutterError?
    {
      plugin?.cacheEventSink = events
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      plugin?.cacheEventSink = nil
      return nil
    }
  }

  private final class CacheTaskBox {
    let taskId: String
    let priority: Int
    private let markQueuedNative: (Int64?) -> Void
    private let start: () -> Void
    private let pause: () -> Void
    private let cancel: () -> Void
    private let snapshotProvider: () -> [String: Any]
    private(set) var status = "queued"
    private var queuedPositionMs: Int64 = 0

    init(
      taskId: String,
      priority: Int,
      markQueued: @escaping (Int64?) -> Void,
      start: @escaping () -> Void,
      pause: @escaping () -> Void,
      cancel: @escaping () -> Void,
      snapshot: @escaping () -> [String: Any]
    ) {
      self.taskId = taskId
      self.priority = priority
      self.markQueuedNative = markQueued
      self.start = start
      self.pause = pause
      self.cancel = cancel
      self.snapshotProvider = snapshot
    }

    var isRunning: Bool { status == "running" }
    var isQueued: Bool { status == "queued" }
    var isPaused: Bool { status == "paused" }

    func markQueued(positionMs: Int64? = nil) {
      if let positionMs {
        queuedPositionMs = max(positionMs, 0)
      }
      status = "queued"
      markQueuedNative(positionMs.map { max($0, 0) })
    }

    func startTask() {
      status = "running"
      start()
    }

    func pauseTask() {
      status = "paused"
      pause()
    }

    func resumeTask() {
      markQueued()
    }

    func cancelTask() {
      status = "cancelled"
      cancel()
    }

    func snapshot() -> [String: Any] {
      var snapshot = snapshotProvider()
      snapshot["taskId"] = taskId
      snapshot["status"] = status
      snapshot["priority"] = priority
      return snapshot
    }
  }

  private func autoQuality() -> [String: Any] {
    [
      "id": "auto",
      "label": "Auto",
      "width": 0,
      "height": 0,
      "bitrate": 0,
      "isAuto": true,
    ]
  }
}
