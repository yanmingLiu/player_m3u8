import 'package:player_m3u8/player_m3u8.dart';

import '../../../shared/localization/example_strings.dart';

const String sampleM3u8Url =
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

const List<VideoSource> sampleVideos = <VideoSource>[
  VideoSource(title: 'Mux Big Buck Bunny', url: sampleM3u8Url),
  VideoSource(
    title: 'Apple Adv (音视频分离)',
    titleEn: 'Apple Advanced (separate audio/video)',
    url:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
    audioUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  ),
  VideoSource(
    title: 'Apple BipBop Advanced (内嵌字幕)',
    titleEn: 'Apple BipBop Advanced (embedded subtitles)',
    url:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  ),
  VideoSource(
    title: 'Elephant\'s Dream (VTT多语言字幕)',
    titleEn: 'Elephant\'s Dream (multi-language VTT)',
    url:
        'https://playertest.longtailvideo.com/adaptive/elephants_dream_v4/index.m3u8',
  ),
  VideoSource(
    title: 'Google Shaka Angel One',
    url:
        'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8',
  ),
  VideoSource(
    title: 'Google Shaka Big Buck Bunny',
    url:
        'https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8',
  ),
  VideoSource(
    title: 'Mux Tears of Steel',
    url: 'https://test-streams.mux.dev/tos_ismc/main.m3u8',
  ),
  VideoSource(
    title: 'Akamai HLS Test',
    url: 'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
  ),
  VideoSource(
    title: 'AWS CloudFront Sintel',
    url: 'https://d2zihajmogu5jn.cloudfront.net/sintel/master.m3u8',
  ),
  VideoSource(
    title: 'MP4 Video.js Oceans',
    url: 'https://vjs.zencdn.net/v/oceans.mp4',
    sourceType: M3u8SourceType.progressive,
  ),
  VideoSource(
    title: 'MP4 W3C Sintel Trailer',
    url: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
    sourceType: M3u8SourceType.progressive,
  ),
  VideoSource(
    title: 'MP4 W3Schools Big Buck Bunny',
    url: 'https://www.w3schools.com/html/mov_bbb.mp4',
    sourceType: M3u8SourceType.progressive,
  ),
  VideoSource(
    title: 'MP4 MDN Flower',
    url:
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    sourceType: M3u8SourceType.progressive,
    subtitles: [
      M3u8SubtitleTrack(
        id: 'flower-en',
        label: 'English',
        language: 'en',
        url:
            'https://interactive-examples.mdn.mozilla.net/media/examples/friday.vtt',
      ),
    ],
  ),
];

class VideoSource {
  const VideoSource({
    required this.title,
    required this.url,
    this.titleEn,
    this.audioUrl,
    this.audioHeaders,
    this.sourceType = M3u8SourceType.auto,
    this.subtitles = const <M3u8SubtitleTrack>[],
  });

  final String title;
  final String? titleEn;
  final String url;
  final String? audioUrl;
  final Map<String, String>? audioHeaders;
  final M3u8SourceType sourceType;
  final List<M3u8SubtitleTrack> subtitles;

  M3u8Source toSource() => M3u8Source(
    videoUrl: url,
    audioUrl: audioUrl,
    audioHeaders: audioHeaders,
    sourceType: sourceType,
  );

  Map<String, Object?> downloadMetadata(ExampleLanguage language) => {
    'title': localizedTitle(language),
    'source': toSource().toMap(),
  };

  bool get supportsPrecache => true;

  String localizedTitle(ExampleLanguage language) {
    if (language == ExampleLanguage.en) {
      return titleEn ?? title;
    }
    return title;
  }
}
