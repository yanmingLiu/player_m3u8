import 'package:flutter/foundation.dart';

import 'm3u8_player_value.dart';

@immutable
class M3u8QoeSnapshot {
  const M3u8QoeSnapshot({
    required this.playerId,
    required this.startedAt,
    required this.endedAt,
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.diskCachePosition,
    required this.startupTime,
    required this.rebufferCount,
    required this.rebufferCountDelta,
    required this.rebufferDuration,
    required this.rebufferDurationDelta,
    required this.droppedFrames,
    required this.droppedFramesDelta,
    required this.recoveryCount,
    required this.recoveryCountDelta,
    required this.qualitySwitchCount,
    required this.qualitySwitchCountDelta,
    required this.videoBitrate,
    required this.observedBitrate,
    required this.selectedQuality,
    required this.isBuffering,
    required this.isPlaying,
    required this.hasError,
  });

  factory M3u8QoeSnapshot.fromValues({
    required int playerId,
    required DateTime startedAt,
    required DateTime endedAt,
    required M3u8PlayerValue previous,
    required M3u8PlayerValue current,
  }) {
    return M3u8QoeSnapshot(
      playerId: playerId,
      startedAt: startedAt,
      endedAt: endedAt,
      position: current.position,
      duration: current.duration,
      bufferedPosition: current.bufferedPosition,
      diskCachePosition: current.diskCachePosition,
      startupTime: current.startupTime,
      rebufferCount: current.rebufferCount,
      rebufferCountDelta: _positiveDelta(
        current.rebufferCount,
        previous.rebufferCount,
      ),
      rebufferDuration: current.rebufferDuration,
      rebufferDurationDelta: _positiveDurationDelta(
        current.rebufferDuration,
        previous.rebufferDuration,
      ),
      droppedFrames: current.droppedFrames,
      droppedFramesDelta: _positiveDelta(
        current.droppedFrames,
        previous.droppedFrames,
      ),
      recoveryCount: current.recoveryCount,
      recoveryCountDelta: _positiveDelta(
        current.recoveryCount,
        previous.recoveryCount,
      ),
      qualitySwitchCount: current.qualitySwitchCount,
      qualitySwitchCountDelta: _positiveDelta(
        current.qualitySwitchCount,
        previous.qualitySwitchCount,
      ),
      videoBitrate: current.videoBitrate,
      observedBitrate: current.observedBitrate,
      selectedQuality: current.selectedQuality,
      isBuffering: current.isBuffering,
      isPlaying: current.isPlaying,
      hasError: current.hasError,
    );
  }

  final int playerId;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final Duration diskCachePosition;
  final Duration startupTime;
  final int rebufferCount;
  final int rebufferCountDelta;
  final Duration rebufferDuration;
  final Duration rebufferDurationDelta;
  final int droppedFrames;
  final int droppedFramesDelta;
  final int recoveryCount;
  final int recoveryCountDelta;
  final int qualitySwitchCount;
  final int qualitySwitchCountDelta;
  final int videoBitrate;
  final int observedBitrate;
  final M3u8Quality selectedQuality;
  final bool isBuffering;
  final bool isPlaying;
  final bool hasError;

  Duration get windowDuration => endedAt.difference(startedAt);

  double get rebufferRatio {
    final windowMs = windowDuration.inMilliseconds;
    if (windowMs <= 0) {
      return 0;
    }
    return rebufferDurationDelta.inMilliseconds / windowMs;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'playerId': playerId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'windowDurationMs': windowDuration.inMilliseconds,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'bufferedPositionMs': bufferedPosition.inMilliseconds,
      'diskCachePositionMs': diskCachePosition.inMilliseconds,
      'startupTimeMs': startupTime.inMilliseconds,
      'rebufferCount': rebufferCount,
      'rebufferCountDelta': rebufferCountDelta,
      'rebufferDurationMs': rebufferDuration.inMilliseconds,
      'rebufferDurationDeltaMs': rebufferDurationDelta.inMilliseconds,
      'rebufferRatio': rebufferRatio,
      'droppedFrames': droppedFrames,
      'droppedFramesDelta': droppedFramesDelta,
      'recoveryCount': recoveryCount,
      'recoveryCountDelta': recoveryCountDelta,
      'qualitySwitchCount': qualitySwitchCount,
      'qualitySwitchCountDelta': qualitySwitchCountDelta,
      'videoBitrate': videoBitrate,
      'observedBitrate': observedBitrate,
      'selectedQuality': selectedQuality.toMap(),
      'isBuffering': isBuffering,
      'isPlaying': isPlaying,
      'hasError': hasError,
    };
  }

  @override
  String toString() {
    return 'M3u8QoeSnapshot('
        'playerId: $playerId, '
        'windowDuration: $windowDuration, '
        'position: $position, '
        'rebufferRatio: $rebufferRatio, '
        'rebufferCountDelta: $rebufferCountDelta, '
        'droppedFramesDelta: $droppedFramesDelta, '
        'recoveryCountDelta: $recoveryCountDelta, '
        'qualitySwitchCountDelta: $qualitySwitchCountDelta'
        ')';
  }
}

int _positiveDelta(int current, int previous) {
  return (current - previous).clamp(0, 1 << 31);
}

Duration _positiveDurationDelta(Duration current, Duration previous) {
  final delta = current - previous;
  if (delta.isNegative) {
    return Duration.zero;
  }
  return delta;
}
