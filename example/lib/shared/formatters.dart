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

String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final decimals = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
}

String formatBytesPerSecond(int bytesPerSecond) {
  return '${formatBytes(bytesPerSecond)}/s';
}

Duration positiveDuration(Duration duration) {
  if (duration.isNegative) {
    return Duration.zero;
  }
  return duration;
}
