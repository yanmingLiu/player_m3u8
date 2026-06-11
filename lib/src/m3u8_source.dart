import 'package:flutter/foundation.dart';

import 'm3u8_source_type.dart';

@immutable
class M3u8Source {
  const M3u8Source({
    required this.videoUrl,
    this.audioUrl,
    this.videoHeaders = const {},
    this.audioHeaders,
    this.sourceType = M3u8SourceType.auto,
    this.cacheKey,
  });

  factory M3u8Source.fromMap(Map<Object?, Object?> map) {
    final videoHeaders = map['videoHeaders'];
    final audioHeaders = map['audioHeaders'];
    return M3u8Source(
      videoUrl: map['videoUrl'] as String? ?? '',
      audioUrl: map['audioUrl'] as String?,
      videoHeaders: videoHeaders is Map
          ? videoHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      audioHeaders: audioHeaders is Map
          ? audioHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : null,
      sourceType: M3u8SourceType.from(map['sourceType'] as String?),
      cacheKey: map['cacheKey'] as String?,
    );
  }

  final String videoUrl;
  final String? audioUrl;
  final Map<String, String> videoHeaders;
  final Map<String, String>? audioHeaders;
  final M3u8SourceType sourceType;
  final String? cacheKey;

  Map<String, String> get effectiveAudioHeaders => audioHeaders ?? videoHeaders;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'videoHeaders': videoHeaders,
      'audioHeaders': audioHeaders,
      'sourceType': sourceType.platformValue,
      'cacheKey': cacheKey,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is M3u8Source &&
        other.videoUrl == videoUrl &&
        other.audioUrl == audioUrl &&
        mapEquals(other.videoHeaders, videoHeaders) &&
        mapEquals(other.audioHeaders, audioHeaders) &&
        other.sourceType == sourceType &&
        other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => Object.hash(
    videoUrl,
    audioUrl,
    videoHeaders,
    audioHeaders,
    sourceType,
    cacheKey,
  );

  @override
  String toString() {
    return 'M3u8Source($videoUrl, audioUrl: $audioUrl, cacheKey: $cacheKey)';
  }
}
