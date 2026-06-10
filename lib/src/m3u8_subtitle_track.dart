import 'package:flutter/foundation.dart';

@immutable
class M3u8SubtitleTrack {
  const M3u8SubtitleTrack({
    required this.id,
    required this.label,
    this.language,
    this.url,
    this.mimeType,
    this.headers = const <String, String>{},
  });

  factory M3u8SubtitleTrack.fromMap(Map<Object?, Object?> map) {
    final headers = map['headers'];
    return M3u8SubtitleTrack(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? map['id'] as String? ?? '',
      language: map['language'] as String?,
      url: map['url'] as String?,
      mimeType: map['mimeType'] as String?,
      headers: headers is Map
          ? headers.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }

  final String id;
  final String label;
  final String? language;
  final String? url;
  final String? mimeType;
  final Map<String, String> headers;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'language': language,
      'url': url,
      'mimeType': mimeType,
      'headers': headers,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is M3u8SubtitleTrack &&
        other.id == id &&
        other.label == label &&
        other.language == language &&
        other.url == url &&
        other.mimeType == mimeType &&
        mapEquals(other.headers, headers);
  }

  @override
  int get hashCode => Object.hash(id, label, language, url, mimeType, headers);

  @override
  String toString() => 'M3u8SubtitleTrack($id, $label)';
}
