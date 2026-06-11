import 'm3u8_cache_event.dart';
import 'm3u8_source_type.dart';

class M3u8CacheTask {
  const M3u8CacheTask({
    required this.taskId,
    required this.url,
    this.owner = M3u8CacheTaskOwner.standalone,
    this.status = M3u8CacheTaskStatus.queued,
    this.sourceType = M3u8SourceType.auto,
    this.priority = 0,
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
    this.event,
    this.metadata = const <String, Object?>{},
  });

  factory M3u8CacheTask.fromMap(Map<Object?, Object?> map) {
    final metadata = map['metadata'];
    return M3u8CacheTask(
      taskId: map['taskId'] as String? ?? '',
      url: map['url'] as String? ?? '',
      owner: M3u8CacheTaskOwner.from(map['owner'] as String?),
      status: M3u8CacheTaskStatus.from(map['status'] as String?),
      sourceType: M3u8SourceType.from(map['sourceType'] as String?),
      priority: _asInt(map['priority']),
      bytesCached: _asInt(map['bytesCached']),
      bytesTotal: _asInt(map['bytesTotal']),
      downloadSpeedBytesPerSecond: _asInt(map['downloadSpeedBytesPerSecond']),
      cacheHitCount: _asInt(map['cacheHitCount']),
      networkFetchCount: _asInt(map['networkFetchCount']),
      segmentIndex: _asInt(map['segmentIndex']),
      segmentCount: _asInt(map['segmentCount']),
      currentUrl: map['currentUrl'] as String?,
      retryCount: _asInt(map['retryCount']),
      updatedAt: _dateTimeFromMs(map['updatedAt']),
      event: M3u8CacheEvent.fromMap(map),
      metadata: metadata is Map
          ? Map<String, Object?>.fromEntries(
              metadata.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : const <String, Object?>{},
    );
  }

  final String taskId;
  final String url;
  final M3u8CacheTaskOwner owner;
  final M3u8CacheTaskStatus status;
  final M3u8SourceType sourceType;
  final int priority;
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
  final M3u8CacheEvent? event;
  final Map<String, Object?> metadata;

  double get progress {
    if (bytesTotal <= 0) {
      return 0;
    }
    return (bytesCached / bytesTotal).clamp(0, 1).toDouble();
  }

  M3u8CacheTask copyWith({
    String? taskId,
    String? url,
    M3u8CacheTaskOwner? owner,
    M3u8CacheTaskStatus? status,
    M3u8SourceType? sourceType,
    int? priority,
    int? bytesCached,
    int? bytesTotal,
    int? downloadSpeedBytesPerSecond,
    int? cacheHitCount,
    int? networkFetchCount,
    int? segmentIndex,
    int? segmentCount,
    Object? currentUrl = _sentinel,
    int? retryCount,
    Object? updatedAt = _sentinel,
    Object? event = _sentinel,
    Map<String, Object?>? metadata,
  }) {
    return M3u8CacheTask(
      taskId: taskId ?? this.taskId,
      url: url ?? this.url,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      sourceType: sourceType ?? this.sourceType,
      priority: priority ?? this.priority,
      bytesCached: bytesCached ?? this.bytesCached,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      downloadSpeedBytesPerSecond:
          downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond,
      cacheHitCount: cacheHitCount ?? this.cacheHitCount,
      networkFetchCount: networkFetchCount ?? this.networkFetchCount,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      segmentCount: segmentCount ?? this.segmentCount,
      currentUrl: identical(currentUrl, _sentinel)
          ? this.currentUrl
          : currentUrl as String?,
      retryCount: retryCount ?? this.retryCount,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
      event: identical(event, _sentinel)
          ? this.event
          : event as M3u8CacheEvent?,
      metadata: metadata ?? this.metadata,
    );
  }
}

const Object _sentinel = Object();

enum M3u8CacheTaskOwner {
  player,
  standalone;

  static M3u8CacheTaskOwner from(String? value) {
    return switch (value) {
      'player' => M3u8CacheTaskOwner.player,
      _ => M3u8CacheTaskOwner.standalone,
    };
  }

  String get platformValue {
    return switch (this) {
      M3u8CacheTaskOwner.player => 'player',
      M3u8CacheTaskOwner.standalone => 'standalone',
    };
  }
}

enum M3u8CacheTaskStatus {
  queued,
  running,
  paused,
  completed,
  cancelled,
  error;

  static M3u8CacheTaskStatus from(String? value) {
    return switch (value) {
      'running' => M3u8CacheTaskStatus.running,
      'paused' => M3u8CacheTaskStatus.paused,
      'completed' => M3u8CacheTaskStatus.completed,
      'cancelled' => M3u8CacheTaskStatus.cancelled,
      'error' => M3u8CacheTaskStatus.error,
      _ => M3u8CacheTaskStatus.queued,
    };
  }

  String get platformValue {
    return switch (this) {
      M3u8CacheTaskStatus.queued => 'queued',
      M3u8CacheTaskStatus.running => 'running',
      M3u8CacheTaskStatus.paused => 'paused',
      M3u8CacheTaskStatus.completed => 'completed',
      M3u8CacheTaskStatus.cancelled => 'cancelled',
      M3u8CacheTaskStatus.error => 'error',
    };
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

DateTime? _dateTimeFromMs(Object? value) {
  final milliseconds = _asInt(value);
  if (milliseconds <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
