import '../player_m3u8_platform_interface.dart';
import 'm3u8_cache_event.dart';
import 'm3u8_cache_info.dart';
import 'm3u8_cache_task.dart';
import 'm3u8_player_value.dart';
import 'm3u8_source.dart';

class M3u8PlayerCache {
  const M3u8PlayerCache._();

  static Future<void> configure({
    int maxSizeBytes = 512 * 1024 * 1024,
    int maxConcurrentPrecacheTasks = 2,
    PlayerM3u8Platform? platform,
  }) {
    if (maxSizeBytes <= 0) {
      throw ArgumentError.value(
        maxSizeBytes,
        'maxSizeBytes',
        'Cache size must be greater than zero.',
      );
    }
    if (maxConcurrentPrecacheTasks <= 0) {
      throw ArgumentError.value(
        maxConcurrentPrecacheTasks,
        'maxConcurrentPrecacheTasks',
        'Must be greater than zero.',
      );
    }
    return (platform ?? PlayerM3u8Platform.instance).configureCache(
      maxSizeBytes: maxSizeBytes,
      maxConcurrentPrecacheTasks: maxConcurrentPrecacheTasks,
    );
  }

  static Future<void> clear({PlayerM3u8Platform? platform}) {
    return (platform ?? PlayerM3u8Platform.instance).clearCache();
  }

  static Future<M3u8CacheInfo> info({PlayerM3u8Platform? platform}) {
    return (platform ?? PlayerM3u8Platform.instance).getCacheInfo();
  }

  static Stream<M3u8CacheEvent> events({PlayerM3u8Platform? platform}) {
    return (platform ?? PlayerM3u8Platform.instance).cacheEvents;
  }

  static Future<String> precache(
    M3u8Source source, {
    Duration initialPosition = Duration.zero,
    M3u8Quality quality = M3u8Quality.auto,
    int priority = 0,
    int maxRetries = 2,
    Map<String, Object?> metadata = const <String, Object?>{},
    PlayerM3u8Platform? platform,
  }) {
    if (initialPosition < Duration.zero) {
      throw ArgumentError.value(
        initialPosition,
        'initialPosition',
        'Must be greater than or equal to zero.',
      );
    }
    if (maxRetries < 0) {
      throw ArgumentError.value(
        maxRetries,
        'maxRetries',
        'Must be greater than or equal to zero.',
      );
    }
    return (platform ?? PlayerM3u8Platform.instance).precache(
      source: source,
      initialPosition: initialPosition,
      quality: quality,
      priority: priority,
      maxRetries: maxRetries,
      metadata: metadata,
    );
  }

  static Future<void> cancelPrecache(
    String taskId, {
    PlayerM3u8Platform? platform,
  }) {
    if (taskId.trim().isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', 'Task id must not be empty.');
    }
    return (platform ?? PlayerM3u8Platform.instance).cancelPrecache(taskId);
  }

  static Future<void> pausePrecache(
    String taskId, {
    PlayerM3u8Platform? platform,
  }) {
    _debugAssertValidTaskId(taskId);
    return (platform ?? PlayerM3u8Platform.instance).pausePrecache(taskId);
  }

  static Future<void> resumePrecache(
    String taskId, {
    PlayerM3u8Platform? platform,
  }) {
    _debugAssertValidTaskId(taskId);
    return (platform ?? PlayerM3u8Platform.instance).resumePrecache(taskId);
  }

  static Future<List<M3u8CacheTask>> tasks({PlayerM3u8Platform? platform}) {
    return (platform ?? PlayerM3u8Platform.instance).cacheTasks();
  }

  static Future<M3u8CacheInfo> sourceInfo(
    M3u8Source source, {
    PlayerM3u8Platform? platform,
  }) {
    return (platform ?? PlayerM3u8Platform.instance).sourceCacheInfo(source);
  }

  static Future<void> clearSource(
    M3u8Source source, {
    PlayerM3u8Platform? platform,
  }) {
    return (platform ?? PlayerM3u8Platform.instance).clearSourceCache(source);
  }
}

void _debugAssertValidTaskId(String taskId) {
  if (taskId.trim().isEmpty) {
    throw ArgumentError.value(taskId, 'taskId', 'Task id must not be empty.');
  }
}
