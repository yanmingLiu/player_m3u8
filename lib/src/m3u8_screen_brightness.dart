import '../player_m3u8_platform_interface.dart';

class M3u8ScreenBrightness {
  const M3u8ScreenBrightness._();

  static Future<double> get() {
    return PlayerM3u8Platform.instance.getScreenBrightness();
  }

  static Future<void> set(double brightness) {
    _debugAssertValidBrightness(brightness);
    return PlayerM3u8Platform.instance.setScreenBrightness(brightness);
  }

  static void _debugAssertValidBrightness(double brightness) {
    if (brightness < 0 ||
        brightness > 1 ||
        brightness.isNaN ||
        brightness.isInfinite) {
      throw ArgumentError.value(
        brightness,
        'brightness',
        'Must be finite and between 0.0 and 1.0.',
      );
    }
  }
}
