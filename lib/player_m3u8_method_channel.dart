import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'player_m3u8_platform_interface.dart';
import 'src/m3u8_player_event.dart';

class MethodChannelPlayerM3u8 extends PlayerM3u8Platform {
  @visibleForTesting
  final MethodChannel methodChannel;

  @visibleForTesting
  final EventChannel eventChannel;

  Stream<M3u8PlayerEvent>? _events;

  MethodChannelPlayerM3u8({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : methodChannel =
           methodChannel ?? const MethodChannel('player_m3u8/methods'),
       eventChannel = eventChannel ?? const EventChannel('player_m3u8/events');

  @override
  Stream<M3u8PlayerEvent> get events {
    return _events ??= eventChannel
        .receiveBroadcastStream()
        .where((Object? event) => event is Map)
        .map((Object? event) {
          final raw = Map<Object?, Object?>.from(event! as Map);
          return M3u8PlayerEvent.fromMap(raw);
        });
  }

  @override
  Future<int> create({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) async {
    try {
      final playerId = await methodChannel.invokeMethod<int>('create', {
        'url': url,
        'headers': headers,
      });
      if (playerId == null) {
        throw PlayerM3u8PlatformException(
          'invalid_player_id',
          'Platform returned a null player id.',
        );
      }
      return playerId;
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }

  @override
  Future<void> play(int playerId) => _invokeVoid('play', playerId);

  @override
  Future<void> pause(int playerId) => _invokeVoid('pause', playerId);

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    try {
      await methodChannel.invokeMethod<void>('seekTo', {
        'playerId': playerId,
        'position': position.inMilliseconds,
      });
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }

  @override
  Future<void> disposePlayer(int playerId) => _invokeVoid('dispose', playerId);

  Future<void> _invokeVoid(String method, int playerId) async {
    try {
      await methodChannel.invokeMethod<void>(method, {'playerId': playerId});
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }
}
