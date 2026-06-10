import '../player_m3u8_platform_interface.dart';
import 'm3u8_cache_event.dart';
import 'm3u8_cache_info.dart';
import 'm3u8_player_value.dart';

class M3u8PlayerCache {
  const M3u8PlayerCache._();

  static Future<void> configure({
    int maxSizeBytes = 512 * 1024 * 1024,
    PlayerM3u8Platform? platform,
  }) {
    if (maxSizeBytes <= 0) {
      throw ArgumentError.value(
        maxSizeBytes,
        'maxSizeBytes',
        'Cache size must be greater than zero.',
      );
    }
    return (platform ?? PlayerM3u8Platform.instance).configureCache(
      maxSizeBytes: maxSizeBytes,
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
    String url, {
    Map<String, String> headers = const <String, String>{},
    Duration initialPosition = Duration.zero,
    M3u8Quality quality = M3u8Quality.auto,
    PlayerM3u8Platform? platform,
  }) {
    if (url.trim().isEmpty) {
      throw ArgumentError.value(url, 'url', 'URL must not be empty.');
    }
    if (initialPosition < Duration.zero) {
      throw ArgumentError.value(
        initialPosition,
        'initialPosition',
        'Must be greater than or equal to zero.',
      );
    }
    return (platform ?? PlayerM3u8Platform.instance).precache(
      url: url,
      headers: headers,
      initialPosition: initialPosition,
      quality: quality,
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
}
