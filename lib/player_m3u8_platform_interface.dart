import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'player_m3u8_method_channel.dart';
import 'src/m3u8_player_event.dart';
import 'src/m3u8_player_value.dart';
import 'src/m3u8_recovery_policy.dart';

abstract class PlayerM3u8Platform extends PlatformInterface {
  PlayerM3u8Platform() : super(token: _token);

  static final Object _token = Object();

  static PlayerM3u8Platform _instance = MethodChannelPlayerM3u8();

  static PlayerM3u8Platform get instance => _instance;

  static set instance(PlayerM3u8Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<M3u8PlayerEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  Future<int> create({
    required String url,
    Map<String, String> headers = const <String, String>{},
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
  }) {
    throw UnimplementedError('create() has not been implemented.');
  }

  Future<void> play(int playerId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  Future<void> pause(int playerId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> seekTo(int playerId, Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  Future<void> setQuality(int playerId, M3u8Quality quality) {
    throw UnimplementedError('setQuality() has not been implemented.');
  }

  Future<void> setRecoveryPolicy(
    int playerId,
    M3u8RecoveryPolicy recoveryPolicy,
  ) {
    throw UnimplementedError('setRecoveryPolicy() has not been implemented.');
  }

  Future<void> setPlaybackSpeed(int playerId, double speed) {
    throw UnimplementedError('setPlaybackSpeed() has not been implemented.');
  }

  Future<void> setVolume(int playerId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<void> setMuted(int playerId, bool isMuted) {
    throw UnimplementedError('setMuted() has not been implemented.');
  }

  Future<void> disposePlayer(int playerId) {
    throw UnimplementedError('disposePlayer() has not been implemented.');
  }

  Future<void> configureCache({required int maxSizeBytes}) {
    throw UnimplementedError('configureCache() has not been implemented.');
  }

  Future<void> clearCache() {
    throw UnimplementedError('clearCache() has not been implemented.');
  }
}

class PlayerM3u8PlatformException implements Exception {
  PlayerM3u8PlatformException(this.code, this.message, [this.details]);

  factory PlayerM3u8PlatformException.fromPlatformException(
    PlatformException exception,
  ) {
    return PlayerM3u8PlatformException(
      exception.code,
      exception.message ?? exception.code,
      exception.details,
    );
  }

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'PlayerM3u8PlatformException($code, $message)';
}
