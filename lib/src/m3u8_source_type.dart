enum M3u8SourceType {
  auto,
  hls,
  progressive;

  String get platformValue => switch (this) {
    M3u8SourceType.auto => 'auto',
    M3u8SourceType.hls => 'hls',
    M3u8SourceType.progressive => 'progressive',
  };

  static M3u8SourceType from(String? value) {
    return switch (value) {
      'hls' => M3u8SourceType.hls,
      'progressive' => M3u8SourceType.progressive,
      _ => M3u8SourceType.auto,
    };
  }
}
