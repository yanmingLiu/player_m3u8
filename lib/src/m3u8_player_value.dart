import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'm3u8_subtitle_track.dart';

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
    this.diskCacheStartPosition = Duration.zero,
    this.diskCachePosition = Duration.zero,
    this.diskCachePercent = 0,
    this.isDiskCacheComplete = false,
    this.startupTime = Duration.zero,
    this.rebufferCount = 0,
    this.rebufferDuration = Duration.zero,
    this.droppedFrames = 0,
    this.videoBitrate = 0,
    this.observedBitrate = 0,
    this.qualitySwitchCount = 0,
    this.availableQualities = const <M3u8Quality>[],
    this.selectedQuality = M3u8Quality.auto,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.isMuted = false,
    this.availableSubtitles = const <M3u8SubtitleTrack>[],
    this.selectedSubtitle,
    this.subtitleText = '',
    this.recoveryCount = 0,
    this.lastRecoveryReason = '',
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
  final Duration diskCacheStartPosition;
  final Duration diskCachePosition;
  final double diskCachePercent;
  final bool isDiskCacheComplete;
  final Duration startupTime;
  final int rebufferCount;
  final Duration rebufferDuration;
  final int droppedFrames;
  final int videoBitrate;
  final int observedBitrate;
  final int qualitySwitchCount;
  final List<M3u8Quality> availableQualities;
  final M3u8Quality selectedQuality;
  final double playbackSpeed;
  final double volume;
  final bool isMuted;
  final List<M3u8SubtitleTrack> availableSubtitles;
  final M3u8SubtitleTrack? selectedSubtitle;
  final String subtitleText;
  final int recoveryCount;
  final String lastRecoveryReason;
  final Size size;
  final M3u8PlayerError? error;

  bool get hasError => error != null;

  Duration get visibleBufferedPosition {
    return diskCachePosition > bufferedPosition
        ? diskCachePosition
        : bufferedPosition;
  }

  Duration get visibleBufferedStartPosition {
    return diskCachePosition > bufferedPosition
        ? diskCacheStartPosition
        : Duration.zero;
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
    Duration? diskCacheStartPosition,
    Duration? diskCachePosition,
    double? diskCachePercent,
    bool? isDiskCacheComplete,
    Duration? startupTime,
    int? rebufferCount,
    Duration? rebufferDuration,
    int? droppedFrames,
    int? videoBitrate,
    int? observedBitrate,
    int? qualitySwitchCount,
    List<M3u8Quality>? availableQualities,
    M3u8Quality? selectedQuality,
    double? playbackSpeed,
    double? volume,
    bool? isMuted,
    List<M3u8SubtitleTrack>? availableSubtitles,
    Object? selectedSubtitle = _sentinel,
    String? subtitleText,
    int? recoveryCount,
    String? lastRecoveryReason,
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
      diskCacheStartPosition:
          diskCacheStartPosition ?? this.diskCacheStartPosition,
      diskCachePosition: diskCachePosition ?? this.diskCachePosition,
      diskCachePercent: diskCachePercent ?? this.diskCachePercent,
      isDiskCacheComplete: isDiskCacheComplete ?? this.isDiskCacheComplete,
      startupTime: startupTime ?? this.startupTime,
      rebufferCount: rebufferCount ?? this.rebufferCount,
      rebufferDuration: rebufferDuration ?? this.rebufferDuration,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      observedBitrate: observedBitrate ?? this.observedBitrate,
      qualitySwitchCount: qualitySwitchCount ?? this.qualitySwitchCount,
      availableQualities: availableQualities ?? this.availableQualities,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      availableSubtitles: availableSubtitles ?? this.availableSubtitles,
      selectedSubtitle: identical(selectedSubtitle, _sentinel)
          ? this.selectedSubtitle
          : selectedSubtitle as M3u8SubtitleTrack?,
      subtitleText: subtitleText ?? this.subtitleText,
      recoveryCount: recoveryCount ?? this.recoveryCount,
      lastRecoveryReason: lastRecoveryReason ?? this.lastRecoveryReason,
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
        'diskCacheStartPosition: $diskCacheStartPosition, '
        'diskCachePosition: $diskCachePosition, '
        'diskCachePercent: $diskCachePercent, '
        'isDiskCacheComplete: $isDiskCacheComplete, '
        'startupTime: $startupTime, '
        'rebufferCount: $rebufferCount, '
        'rebufferDuration: $rebufferDuration, '
        'droppedFrames: $droppedFrames, '
        'videoBitrate: $videoBitrate, '
        'observedBitrate: $observedBitrate, '
        'qualitySwitchCount: $qualitySwitchCount, '
        'availableQualities: $availableQualities, '
        'selectedQuality: $selectedQuality, '
        'playbackSpeed: $playbackSpeed, '
        'volume: $volume, '
        'isMuted: $isMuted, '
        'availableSubtitles: $availableSubtitles, '
        'selectedSubtitle: $selectedSubtitle, '
        'subtitleText: $subtitleText, '
        'recoveryCount: $recoveryCount, '
        'lastRecoveryReason: $lastRecoveryReason, '
        'size: $size, '
        'error: $error'
        ')';
  }
}

@immutable
class M3u8Quality {
  const M3u8Quality({
    required this.id,
    required this.label,
    this.width = 0,
    this.height = 0,
    this.bitrate = 0,
    this.isAuto = false,
  });

  static const M3u8Quality auto = M3u8Quality(
    id: 'auto',
    label: 'Auto',
    isAuto: true,
  );

  factory M3u8Quality.fromMap(Map<Object?, Object?> map) {
    final isAuto = map['isAuto'] as bool? ?? false;
    if (isAuto) {
      return auto;
    }
    final height = _asIntOrZero(map['height']);
    final bitrate = _asIntOrZero(map['bitrate']);
    return M3u8Quality(
      id: map['id'] as String? ?? _qualityId(height, bitrate),
      label: map['label'] as String? ?? _qualityLabel(height, bitrate),
      width: _asIntOrZero(map['width']),
      height: height,
      bitrate: bitrate,
    );
  }

  final String id;
  final String label;
  final int width;
  final int height;
  final int bitrate;
  final bool isAuto;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'width': width,
      'height': height,
      'bitrate': bitrate,
      'isAuto': isAuto,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is M3u8Quality &&
        other.id == id &&
        other.label == label &&
        other.width == width &&
        other.height == height &&
        other.bitrate == bitrate &&
        other.isAuto == isAuto;
  }

  @override
  int get hashCode => Object.hash(id, label, width, height, bitrate, isAuto);

  @override
  String toString() => 'M3u8Quality($id, $label)';
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

int _asIntOrZero(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

String _qualityId(int height, int bitrate) {
  if (height > 0) {
    return '${height}p';
  }
  if (bitrate > 0) {
    return '${bitrate}bps';
  }
  return 'unknown';
}

String _qualityLabel(int height, int bitrate) {
  if (height > 0) {
    return '${height}p';
  }
  if (bitrate > 0) {
    return '${(bitrate / 1000).round()} Kbps';
  }
  return 'Unknown';
}
