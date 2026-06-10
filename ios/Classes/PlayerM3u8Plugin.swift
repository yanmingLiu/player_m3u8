import AVFoundation
import Flutter
import UIKit

public class PlayerM3u8Plugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var textureRegistry: FlutterTextureRegistry
  private var eventSink: FlutterEventSink?
  private var cacheEventSink: FlutterEventSink?
  private var players: [Int64: M3u8IosPlayer] = [:]
  private var cacheTasks: [String: M3u8DiskCachePrefetcher] = [:]

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
    case "precache":
      precache(call: call, result: result)
    case "cancelPrecache":
      cancelPrecache(call: call, result: result)
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
      let urlString = arguments["url"] as? String,
      let url = URL(string: urlString)
    else {
      result(FlutterError(code: "invalid_url", message: "url is required.", details: nil))
      return
    }
    let headers = arguments["headers"] as? [String: String] ?? [:]
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
    let player = M3u8IosPlayer(
      url: url,
      headers: headers,
      initialPositionMs: initialPositionMs,
      playbackSpeed: validPlaybackSpeed(from: arguments["playbackSpeed"]),
      volume: validVolume(from: arguments["volume"]),
      isMuted: arguments["isMuted"] as? Bool ?? false,
      recoveryPolicy: M3u8RecoveryPolicy.from(arguments["recoveryPolicy"] as? [String: Any]),
      textureRegistry: textureRegistry,
      eventSinkProvider: { [weak self] in self?.eventSink }
    )
    let textureId = textureRegistry.register(player)
    player.textureId = textureId
    players[textureId] = player
    result(textureId)
  }

  private func validPlaybackSpeed(from value: Any?) -> Double {
    guard let speed = (value as? NSNumber)?.doubleValue,
      speed.isFinite,
      speed >= 0.25,
      speed <= 2.0
    else {
      return 1.0
    }
    return speed
  }

  private func validVolume(from value: Any?) -> Double {
    guard let volume = (value as? NSNumber)?.doubleValue,
      volume.isFinite,
      volume >= 0,
      volume <= 1
    else {
      return 1.0
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
    guard players.isEmpty else {
      result(
        FlutterError(
          code: "active_players",
          message: "Cache cannot be configured while players are active.",
          details: nil
        )
      )
      return
    }
    guard cacheTasks.isEmpty else {
      result(
        FlutterError(
          code: "active_cache_tasks",
          message: "Cache cannot be configured while cache tasks are active.",
          details: nil
        )
      )
      return
    }
    do {
      try M3u8IosCacheManager.shared.configure(maxSizeBytes: maxSizeBytes.int64Value)
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

  private func precache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let urlString = arguments["url"] as? String,
      !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let url = URL(string: urlString)
    else {
      result(FlutterError(code: "invalid_url", message: "url is required.", details: nil))
      return
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
    let headers = arguments["headers"] as? [String: String] ?? [:]
    let quality = arguments["quality"] as? [String: Any] ?? autoQuality()
    let taskId = UUID().uuidString
    let prefetcher = M3u8DiskCachePrefetcher(
      url: url,
      headers: headers,
      playerIdProvider: { -1 },
      eventSinkProvider: { [weak self] in self?.cacheEventSink },
      taskId: taskId,
      onFinished: { [weak self] in self?.cacheTasks.removeValue(forKey: taskId) },
      qualityProvider: { quality }
    )
    cacheTasks[taskId] = prefetcher
    prefetcher.restart(from: initialPositionMs)
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
    cacheTasks.removeValue(forKey: taskId)?.cancel()
    cacheEventSink?([
      "taskId": taskId,
      "event": "cancelled",
    ])
    result(nil)
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
