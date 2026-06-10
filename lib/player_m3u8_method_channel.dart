import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'player_m3u8_platform_interface.dart';
import 'src/m3u8_player_event.dart';
import 'src/m3u8_player_value.dart';
import 'src/m3u8_recovery_policy.dart';

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
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
  }) async {
    recoveryPolicy.debugAssertValid();
    try {
      final playerId = await methodChannel.invokeMethod<int>('create', {
        'url': url,
        'headers': headers,
        'recoveryPolicy': recoveryPolicy.toMap(),
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

  @override
  Future<void> setQuality(int playerId, M3u8Quality quality) async {
    try {
      await methodChannel.invokeMethod<void>('setQuality', {
        'playerId': playerId,
        'quality': quality.toMap(),
      });
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }

  @override
  Future<void> setRecoveryPolicy(
    int playerId,
    M3u8RecoveryPolicy recoveryPolicy,
  ) async {
    recoveryPolicy.debugAssertValid();
    try {
      await methodChannel.invokeMethod<void>('setRecoveryPolicy', {
        'playerId': playerId,
        'recoveryPolicy': recoveryPolicy.toMap(),
      });
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }

  @override
  Future<void> configureCache({required int maxSizeBytes}) async {
    try {
      await methodChannel.invokeMethod<void>('configureCache', {
        'maxSizeBytes': maxSizeBytes,
      });
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await methodChannel.invokeMethod<void>('clearCache');
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }

  Future<void> _invokeVoid(String method, int playerId) async {
    try {
      await methodChannel.invokeMethod<void>(method, {'playerId': playerId});
    } on PlatformException catch (error) {
      throw PlayerM3u8PlatformException.fromPlatformException(error);
    }
  }
}
