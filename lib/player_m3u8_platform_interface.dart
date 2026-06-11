import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'player_m3u8_method_channel.dart';
import 'src/m3u8_cache_event.dart';
import 'src/m3u8_cache_info.dart';
import 'src/m3u8_cache_task.dart';
import 'src/m3u8_player_event.dart';
import 'src/m3u8_player_value.dart';
import 'src/m3u8_recovery_policy.dart';
import 'src/m3u8_source.dart';
import 'src/m3u8_subtitle_track.dart';

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

  Stream<M3u8CacheEvent> get cacheEvents {
    throw UnimplementedError('cacheEvents has not been implemented.');
  }

  Future<int> create({
    required M3u8Source source,
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
    List<M3u8SubtitleTrack> subtitles = const <M3u8SubtitleTrack>[],
    String? selectedSubtitleId,
    String? selectedAudioTrackId,
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

  Future<void> setSubtitle(int playerId, String? subtitleId) {
    throw UnimplementedError('setSubtitle() has not been implemented.');
  }

  Future<void> setAudioTrack(int playerId, String? audioTrackId) {
    throw UnimplementedError('setAudioTrack() has not been implemented.');
  }

  Future<void> disposePlayer(int playerId) {
    throw UnimplementedError('disposePlayer() has not been implemented.');
  }

  Future<void> configureCache({
    required int maxSizeBytes,
    int maxConcurrentPrecacheTasks = 2,
  }) {
    throw UnimplementedError('configureCache() has not been implemented.');
  }

  Future<void> clearCache() {
    throw UnimplementedError('clearCache() has not been implemented.');
  }

  Future<M3u8CacheInfo> getCacheInfo() {
    throw UnimplementedError('getCacheInfo() has not been implemented.');
  }

  Future<String> precache({
    required M3u8Source source,
    Duration initialPosition = Duration.zero,
    M3u8Quality quality = M3u8Quality.auto,
    int priority = 0,
    int maxRetries = 2,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    throw UnimplementedError('precache() has not been implemented.');
  }

  Future<void> cancelPrecache(String taskId) {
    throw UnimplementedError('cancelPrecache() has not been implemented.');
  }

  Future<void> pausePrecache(String taskId) {
    throw UnimplementedError('pausePrecache() has not been implemented.');
  }

  Future<void> resumePrecache(String taskId) {
    throw UnimplementedError('resumePrecache() has not been implemented.');
  }

  Future<List<M3u8CacheTask>> cacheTasks() {
    throw UnimplementedError('cacheTasks() has not been implemented.');
  }

  Future<M3u8CacheInfo> sourceCacheInfo(M3u8Source source) {
    throw UnimplementedError('sourceCacheInfo() has not been implemented.');
  }

  Future<void> clearSourceCache(M3u8Source source) {
    throw UnimplementedError('clearSourceCache() has not been implemented.');
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
