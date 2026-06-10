import 'dart:ui';

import 'm3u8_subtitle_track.dart';
import 'm3u8_player_value.dart';

enum M3u8PlayerEventType {
  initialized,
  buffering,
  progress,
  playing,
  paused,
  completed,
  diskCache,
  error,
}

class M3u8PlayerEvent {
  const M3u8PlayerEvent({
    required this.playerId,
    required this.type,
    this.position,
    this.duration,
    this.bufferedPosition,
    this.diskCacheStartPosition,
    this.diskCachePosition,
    this.diskCachePercent,
    this.isDiskCacheComplete,
    this.startupTime,
    this.rebufferCount,
    this.rebufferDuration,
    this.droppedFrames,
    this.videoBitrate,
    this.observedBitrate,
    this.qualitySwitchCount,
    this.availableQualities,
    this.selectedQuality,
    this.playbackSpeed,
    this.volume,
    this.isMuted,
    this.availableSubtitles,
    this.selectedSubtitle,
    this.subtitleText,
    this.recoveryCount,
    this.lastRecoveryReason,
    this.size,
    this.error,
  });

  factory M3u8PlayerEvent.fromMap(Map<Object?, Object?> map) {
    final typeName = map['event'] as String? ?? 'progress';
    final errorMap = map['error'];
    return M3u8PlayerEvent(
      playerId: _asInt(map['playerId']),
      type: _eventTypeFor(typeName),
      position: _durationFromMs(map['position']),
      duration: _durationFromMs(map['duration']),
      bufferedPosition: _durationFromMs(map['bufferedPosition']),
      diskCacheStartPosition: _durationFromMs(map['diskCacheStartPosition']),
      diskCachePosition: _durationFromMs(map['diskCachePosition']),
      diskCachePercent: _asNullableDouble(map['diskCachePercent']),
      isDiskCacheComplete: map['isDiskCacheComplete'] as bool?,
      startupTime: _durationFromMs(map['startupTime']),
      rebufferCount: _asNullableInt(map['rebufferCount']),
      rebufferDuration: _durationFromMs(map['rebufferDuration']),
      droppedFrames: _asNullableInt(map['droppedFrames']),
      videoBitrate: _asNullableInt(map['videoBitrate']),
      observedBitrate: _asNullableInt(map['observedBitrate']),
      qualitySwitchCount: _asNullableInt(map['qualitySwitchCount']),
      availableQualities: _qualitiesFromMap(map['availableQualities']),
      selectedQuality: _qualityFromMap(map['selectedQuality']),
      playbackSpeed: _asNullableDouble(map['playbackSpeed']),
      volume: _asNullableDouble(map['volume']),
      isMuted: map['isMuted'] as bool?,
      availableSubtitles: _subtitlesFromMap(map['availableSubtitles']),
      selectedSubtitle: _subtitleFromMap(map['selectedSubtitle']),
      subtitleText: map['subtitleText'] as String?,
      recoveryCount: _asNullableInt(map['recoveryCount']),
      lastRecoveryReason: map['lastRecoveryReason'] as String?,
      size: _sizeFromMap(map),
      error: errorMap is Map
          ? M3u8PlayerError(
              code: errorMap['code'] as String? ?? 'player_error',
              message: errorMap['message'] as String? ?? 'Playback failed.',
              details: errorMap['details'],
            )
          : null,
    );
  }

  final int playerId;
  final M3u8PlayerEventType type;
  final Duration? position;
  final Duration? duration;
  final Duration? bufferedPosition;
  final Duration? diskCacheStartPosition;
  final Duration? diskCachePosition;
  final double? diskCachePercent;
  final bool? isDiskCacheComplete;
  final Duration? startupTime;
  final int? rebufferCount;
  final Duration? rebufferDuration;
  final int? droppedFrames;
  final int? videoBitrate;
  final int? observedBitrate;
  final int? qualitySwitchCount;
  final List<M3u8Quality>? availableQualities;
  final M3u8Quality? selectedQuality;
  final double? playbackSpeed;
  final double? volume;
  final bool? isMuted;
  final List<M3u8SubtitleTrack>? availableSubtitles;
  final M3u8SubtitleTrack? selectedSubtitle;
  final String? subtitleText;
  final int? recoveryCount;
  final String? lastRecoveryReason;
  final Size? size;
  final M3u8PlayerError? error;
}

M3u8PlayerEventType _eventTypeFor(String type) {
  return switch (type) {
    'initialized' => M3u8PlayerEventType.initialized,
    'buffering' => M3u8PlayerEventType.buffering,
    'playing' => M3u8PlayerEventType.playing,
    'paused' => M3u8PlayerEventType.paused,
    'completed' => M3u8PlayerEventType.completed,
    'diskCache' => M3u8PlayerEventType.diskCache,
    'error' => M3u8PlayerEventType.error,
    _ => M3u8PlayerEventType.progress,
  };
}

Duration? _durationFromMs(Object? value) {
  final milliseconds = _asNullableInt(value);
  if (milliseconds == null || milliseconds < 0) {
    return null;
  }
  return Duration(milliseconds: milliseconds);
}

Size? _sizeFromMap(Map<Object?, Object?> map) {
  final width = _asNullableDouble(map['width']);
  final height = _asNullableDouble(map['height']);
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return Size(width, height);
}

int _asInt(Object? value) {
  final result = _asNullableInt(value);
  if (result == null) {
    throw ArgumentError.value(value, 'value', 'Expected an integer.');
  }
  return result;
}

int? _asNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _asNullableDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

List<M3u8Quality>? _qualitiesFromMap(Object? value) {
  if (value is! List) {
    return null;
  }
  return value
      .whereType<Map>()
      .map((map) => M3u8Quality.fromMap(Map<Object?, Object?>.from(map)))
      .toList(growable: false);
}

M3u8Quality? _qualityFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return M3u8Quality.fromMap(Map<Object?, Object?>.from(value));
}

List<M3u8SubtitleTrack>? _subtitlesFromMap(Object? value) {
  if (value is! List) {
    return null;
  }
  return value
      .whereType<Map>()
      .map((map) => M3u8SubtitleTrack.fromMap(Map<Object?, Object?>.from(map)))
      .where((track) => track.id.isNotEmpty)
      .toList(growable: false);
}

M3u8SubtitleTrack? _subtitleFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final track = M3u8SubtitleTrack.fromMap(Map<Object?, Object?>.from(value));
  return track.id.isEmpty ? null : track;
}
