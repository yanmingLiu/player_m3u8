import '../player_m3u8_platform_interface.dart';

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
}
