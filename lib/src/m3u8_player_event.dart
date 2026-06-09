import 'dart:ui';

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
    this.diskCachePosition,
    this.isDiskCacheComplete,
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
      diskCachePosition: _durationFromMs(map['diskCachePosition']),
      isDiskCacheComplete: map['isDiskCacheComplete'] as bool?,
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
  final Duration? diskCachePosition;
  final bool? isDiskCacheComplete;
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
