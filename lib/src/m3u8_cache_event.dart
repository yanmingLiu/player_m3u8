import 'm3u8_player_value.dart';
import 'm3u8_source_type.dart';

enum M3u8CacheEventType { progress, completed, cancelled, error }

enum M3u8CacheEventOwner {
  player,
  standalone;

  static M3u8CacheEventOwner from(String? value) {
    return switch (value) {
      'player' => M3u8CacheEventOwner.player,
      _ => M3u8CacheEventOwner.standalone,
    };
  }
}

enum M3u8CacheEventStatus {
  queued,
  running,
  paused,
  completed,
  cancelled,
  error;

  static M3u8CacheEventStatus from(String? value, M3u8CacheEventType type) {
    return switch (value) {
      'queued' => M3u8CacheEventStatus.queued,
      'running' => M3u8CacheEventStatus.running,
      'paused' => M3u8CacheEventStatus.paused,
      'completed' => M3u8CacheEventStatus.completed,
      'cancelled' => M3u8CacheEventStatus.cancelled,
      'error' => M3u8CacheEventStatus.error,
      _ => switch (type) {
        M3u8CacheEventType.completed => M3u8CacheEventStatus.completed,
        M3u8CacheEventType.cancelled => M3u8CacheEventStatus.cancelled,
        M3u8CacheEventType.error => M3u8CacheEventStatus.error,
        M3u8CacheEventType.progress => M3u8CacheEventStatus.running,
      },
    };
  }
}

class M3u8CacheEvent {
  const M3u8CacheEvent({
    required this.taskId,
    required this.url,
    required this.type,
    this.playerId,
    this.owner = M3u8CacheEventOwner.standalone,
    this.status = M3u8CacheEventStatus.running,
    this.sourceType = M3u8SourceType.auto,
    this.priority = 0,
    this.duration,
    this.startPosition,
    this.position,
    this.percent,
    this.isComplete = false,
    this.quality,
    this.bytesCached = 0,
    this.bytesTotal = 0,
    this.downloadSpeedBytesPerSecond = 0,
    this.cacheHitCount = 0,
    this.networkFetchCount = 0,
    this.segmentIndex = 0,
    this.segmentCount = 0,
    this.currentUrl,
    this.retryCount = 0,
    this.updatedAt,
    this.metadata = const <String, Object?>{},
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
      playerId: _asNullableInt(map['playerId']),
      owner: _ownerFromMap(map, type),
      status: M3u8CacheEventStatus.from(map['status'] as String?, type),
      sourceType: M3u8SourceType.from(map['sourceType'] as String?),
      priority: _asNullableInt(map['priority']) ?? 0,
      duration: _durationFromMs(map['duration']),
      startPosition: _durationFromMs(
        map['startPosition'] ?? map['diskCacheStartPosition'],
      ),
      position: _durationFromMs(map['position'] ?? map['diskCachePosition']),
      percent: _asNullableDouble(map['percent'] ?? map['diskCachePercent']),
      isComplete: type == M3u8CacheEventType.completed,
      quality: _qualityFromMap(map['quality']),
      bytesCached: _asNullableInt(map['bytesCached']) ?? 0,
      bytesTotal: _asNullableInt(map['bytesTotal']) ?? 0,
      downloadSpeedBytesPerSecond:
          _asNullableInt(map['downloadSpeedBytesPerSecond']) ?? 0,
      cacheHitCount: _asNullableInt(map['cacheHitCount']) ?? 0,
      networkFetchCount: _asNullableInt(map['networkFetchCount']) ?? 0,
      segmentIndex: _asNullableInt(map['segmentIndex']) ?? 0,
      segmentCount: _asNullableInt(map['segmentCount']) ?? 0,
      currentUrl: map['currentUrl'] as String?,
      retryCount: _asNullableInt(map['retryCount']) ?? 0,
      updatedAt: _dateTimeFromMs(map['updatedAt']),
      metadata: _metadataFromMap(map['metadata']),
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
  final int? playerId;
  final M3u8CacheEventOwner owner;
  final M3u8CacheEventStatus status;
  final M3u8SourceType sourceType;
  final int priority;
  final Duration? duration;
  final Duration? startPosition;
  final Duration? position;
  final double? percent;
  final bool isComplete;
  final M3u8Quality? quality;
  final int bytesCached;
  final int bytesTotal;
  final int downloadSpeedBytesPerSecond;
  final int cacheHitCount;
  final int networkFetchCount;
  final int segmentIndex;
  final int segmentCount;
  final String? currentUrl;
  final int retryCount;
  final DateTime? updatedAt;
  final Map<String, Object?> metadata;
  final M3u8PlayerError? error;

  double get byteProgress {
    if (bytesTotal <= 0) {
      return 0;
    }
    return (bytesCached / bytesTotal).clamp(0, 1).toDouble();
  }
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

M3u8CacheEventOwner _ownerFromMap(
  Map<Object?, Object?> map,
  M3u8CacheEventType type,
) {
  final owner = map['owner'] as String?;
  if (owner != null) {
    return M3u8CacheEventOwner.from(owner);
  }
  if ((map['taskId'] as String? ?? '').isEmpty &&
      type == M3u8CacheEventType.progress) {
    return M3u8CacheEventOwner.player;
  }
  return M3u8CacheEventOwner.standalone;
}

DateTime? _dateTimeFromMs(Object? value) {
  final milliseconds = _asNullableInt(value);
  if (milliseconds == null || milliseconds <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

Map<String, Object?> _metadataFromMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.fromEntries(
    value.entries.map((entry) => MapEntry(entry.key.toString(), entry.value)),
  );
}
