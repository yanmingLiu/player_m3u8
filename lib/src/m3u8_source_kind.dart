enum M3u8SourceKind {
  network,
  file,
  asset;

  static M3u8SourceKind from(String? value) {
    return switch (value) {
      'file' => M3u8SourceKind.file,
      'asset' => M3u8SourceKind.asset,
      _ => M3u8SourceKind.network,
    };
  }
}
