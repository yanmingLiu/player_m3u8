import 'package:player_m3u8/player_m3u8.dart';

import 'example_strings.dart';

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String speedLabel(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.toStringAsFixed(0)}x';
  }
  return '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
}

double nearestSpeed(double speed, List<double> speeds) {
  return speeds.reduce((double previous, double next) {
    final previousDelta = (previous - speed).abs();
    final nextDelta = (next - speed).abs();
    return nextDelta < previousDelta ? next : previous;
  });
}

String qualityLabel(M3u8Quality quality, ExampleStrings strings) {
  if (quality.id == M3u8Quality.auto.id) {
    return strings.autoQualityLabel;
  }
  return quality.label;
}

Duration positiveDuration(Duration duration) {
  if (duration.isNegative) {
    return Duration.zero;
  }
  return duration;
}
