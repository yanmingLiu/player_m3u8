import 'package:flutter/foundation.dart';

import 'm3u8_player_value.dart';

void debugLogPlayerError({
  required String context,
  required M3u8PlayerError error,
  Map<String, Object?> diagnostics = const <String, Object?>{},
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'player_m3u8[$context] '
    'code=${error.code} '
    'message=${error.message} '
    'details=${error.details} '
    'diagnostics=$diagnostics',
  );
}

void debugLogPlatformException({
  required String context,
  required Object error,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('player_m3u8[$context] $error');
}
