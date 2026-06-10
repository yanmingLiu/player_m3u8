import 'm3u8_player_value.dart';

enum M3u8CacheEventType { progress, completed, cancelled, error }

class M3u8CacheEvent {
  const M3u8CacheEvent({
    required this.taskId,
    required this.url,
    required this.type,
    this.duration,
    this.startPosition,
    this.position,
    this.percent,
    this.isComplete = false,
    this.quality,
    this.error,
  });

  factory M3u8CacheEvent.fromMap(Map<Object?, Object?> map) {
    final hasCompleteFlag = map['isDiskCacheComplete'] == true;
    final type = hasCompleteFlag
        ? M3u8CacheEventType.completed
        : _eventTypeFor(map['event'] as String?);
    final errorMap = map['error'];
    return M3u8CacheEvent(
      taskId: map['taskId'] as String? ?? '',
      url: map['url'] as String? ?? '',
      type: type,
      duration: _durationFromMs(map['duration']),
      startPosition: _durationFromMs(
        map['startPosition'] ?? map['diskCacheStartPosition'],
      ),
      position: _durationFromMs(map['position'] ?? map['diskCachePosition']),
      percent: _asNullableDouble(map['percent'] ?? map['diskCachePercent']),
      isComplete: type == M3u8CacheEventType.completed,
      quality: _qualityFromMap(map['quality']),
      error: errorMap is Map
          ? M3u8PlayerError(
              code: errorMap['code'] as String? ?? 'cache_error',
              message: errorMap['message'] as String? ?? 'Cache task failed.',
              details: errorMap['details'],
            )
          : null,
    );
  }

  final String taskId;
  final String url;
  final M3u8CacheEventType type;
  final Duration? duration;
  final Duration? startPosition;
  final Duration? position;
  final double? percent;
  final bool isComplete;
  final M3u8Quality? quality;
  final M3u8PlayerError? error;
}

M3u8CacheEventType _eventTypeFor(String? type) {
  return switch (type) {
    'completed' => M3u8CacheEventType.completed,
    'cancelled' => M3u8CacheEventType.cancelled,
    'error' => M3u8CacheEventType.error,
    _ => M3u8CacheEventType.progress,
  };
}

Duration? _durationFromMs(Object? value) {
  final milliseconds = _asNullableInt(value);
  if (milliseconds == null || milliseconds < 0) {
    return null;
  }
  return Duration(milliseconds: milliseconds);
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

M3u8Quality? _qualityFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return M3u8Quality.fromMap(Map<Object?, Object?>.from(value));
}
