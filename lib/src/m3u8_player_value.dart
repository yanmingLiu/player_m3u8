import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class M3u8PlayerValue {
  const M3u8PlayerValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.diskCachePosition = Duration.zero,
    this.isDiskCacheComplete = false,
    this.size = Size.zero,
    this.error,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final Duration diskCachePosition;
  final bool isDiskCacheComplete;
  final Size size;
  final M3u8PlayerError? error;

  bool get hasError => error != null;

  Duration get visibleBufferedPosition {
    return diskCachePosition > bufferedPosition
        ? diskCachePosition
        : bufferedPosition;
  }

  double get aspectRatio {
    if (size.width <= 0 || size.height <= 0) {
      return 16 / 9;
    }
    return size.width / size.height;
  }

  M3u8PlayerValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    Duration? diskCachePosition,
    bool? isDiskCacheComplete,
    Size? size,
    Object? error = _sentinel,
  }) {
    return M3u8PlayerValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      diskCachePosition: diskCachePosition ?? this.diskCachePosition,
      isDiskCacheComplete: isDiskCacheComplete ?? this.isDiskCacheComplete,
      size: size ?? this.size,
      error: identical(error, _sentinel)
          ? this.error
          : error as M3u8PlayerError?,
    );
  }

  @override
  String toString() {
    return 'M3u8PlayerValue('
        'isInitialized: $isInitialized, '
        'isPlaying: $isPlaying, '
        'isBuffering: $isBuffering, '
        'isCompleted: $isCompleted, '
        'position: $position, '
        'duration: $duration, '
        'bufferedPosition: $bufferedPosition, '
        'diskCachePosition: $diskCachePosition, '
        'isDiskCacheComplete: $isDiskCacheComplete, '
        'size: $size, '
        'error: $error'
        ')';
  }
}

@immutable
class M3u8PlayerError {
  const M3u8PlayerError({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'M3u8PlayerError($code, $message)';
}

const Object _sentinel = Object();
