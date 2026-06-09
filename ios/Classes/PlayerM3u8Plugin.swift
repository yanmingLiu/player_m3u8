import AVFoundation
import Flutter
import UIKit

public class PlayerM3u8Plugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var textureRegistry: FlutterTextureRegistry
  private var eventSink: FlutterEventSink?
  private var players: [Int64: M3u8IosPlayer] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "player_m3u8/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "player_m3u8/events",
      binaryMessenger: registrar.messenger()
    )
    let instance = PlayerM3u8Plugin(textureRegistry: registrar.textures())
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
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
    let player = M3u8IosPlayer(
      url: url,
      headers: headers,
      textureRegistry: textureRegistry,
      eventSinkProvider: { [weak self] in self?.eventSink }
    )
    let textureId = textureRegistry.register(player)
    player.textureId = textureId
    players[textureId] = player
    result(textureId)
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
}
