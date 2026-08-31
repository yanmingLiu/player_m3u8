class DramaEpisode {
  const DramaEpisode({
    required this.number,
    required this.video,
    required this.cover,
    required this.duration,
    required this.seriesTitle,
    required this.seriesId,
  });
  final int number;
  final String video;
  final String cover;
  final int duration;
  final String seriesTitle;
  final String seriesId;
  factory DramaEpisode.fromMap(
    Map<String, dynamic> m, {
    required String seriesTitle,
    required String seriesId,
  }) => DramaEpisode(
    number: (m['number'] as num?)?.toInt() ?? 0,
    video: _stringValue(m['video']),
    cover: _stringValue(m['cover']),
    duration: (m['duration'] as num?)?.toInt() ?? 0,
    seriesTitle: seriesTitle,
    seriesId: seriesId,
  );
}

class DramaSeries {
  const DramaSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.episodes,
  });
  final String id, title, description;
  final List<String> tags;
  final List<DramaEpisode> episodes;
  factory DramaSeries.fromMap(Map<String, dynamic> m) {
    final id = _stringValue(m['playletId']);
    final title = _stringValue(m['title'], fallback: '未命名剧集');
    final raw = m['episodes'] is List ? m['episodes'] as List : const [];
    return DramaSeries(
      id: id,
      title: title,
      description: _stringValue(m['description']),
      tags: (m['tags'] is List
          ? (m['tags'] as List).whereType<String>().toList(growable: false)
          : const []),
      episodes: raw
          .whereType<Map>()
          .map(
            (e) => DramaEpisode.fromMap(
              Map<String, dynamic>.from(e),
              seriesTitle: title,
              seriesId: id,
            ),
          )
          .where((e) => e.video.isNotEmpty)
          .toList(growable: false),
    );
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}
