import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';

import 'src/buffered_seek_bar.dart';
import 'src/example_strings.dart';
import 'src/player_formatters.dart';
import 'src/video_scaffold.dart';

const String sampleM3u8Url =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';

const List<VideoSource> sampleVideos = <VideoSource>[
  VideoSource(title: 'Apple BipBop', url: sampleM3u8Url),
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

void main() {
  runApp(const PlayerM3u8ExampleApp());
}

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

  bool get supportsPrecache => sourceType != M3u8SourceType.progressive;

  String localizedTitle(ExampleLanguage language) {
    if (language == ExampleLanguage.en) {
      return titleEn ?? title;
    }
    return title;
  }
}

class PlayerM3u8ExampleApp extends StatelessWidget {
  const PlayerM3u8ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: const ExampleStrings(ExampleLanguage.zh).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const PlayerExamplePage(),
    );
  }
}

typedef M3u8ControllerFactory = M3u8PlayerController Function();

class PlayerExamplePage extends StatefulWidget {
  const PlayerExamplePage({
    super.key,
    this.controllerFactory,
    this.autoInitialize = true,
  });

  final M3u8ControllerFactory? controllerFactory;
  final bool autoInitialize;

  @override
  State<PlayerExamplePage> createState() => _PlayerExamplePageState();
}

class _PlayerExamplePageState extends State<PlayerExamplePage> {
  late final M3u8PlayerController _controller;
  StreamSubscription<M3u8QoeSnapshot>? _qoeSubscription;
  StreamSubscription<M3u8CacheEvent>? _cacheSubscription;
  final List<M3u8QoeSnapshot> _qoeSnapshots = <M3u8QoeSnapshot>[];
  ExampleLanguage _language = ExampleLanguage.zh;
  bool _initializing = true;
  bool _switching = false;
  bool _isFullscreen = false;
  bool _autoPlayNext = true;
  ExampleLoopMode _loopMode = ExampleLoopMode.none;
  bool _handledCompletion = false;
  int _currentVideoIndex = 0;
  String? _precacheTaskId;
  M3u8CacheEvent? _latestCacheEvent;

  ExampleStrings get _strings => ExampleStrings(_language);

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerFactory?.call() ?? M3u8PlayerController();
    _qoeSubscription = _controller.qoeSnapshots.listen(_handleQoeSnapshot);
    _cacheSubscription = M3u8PlayerCache.events().listen(_handleCacheEvent);
    if (widget.autoInitialize) {
      _initialize();
    } else {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _qoeSubscription?.cancel();
    _cacheSubscription?.cancel();
    _cancelPrecacheTaskSilently();
    unawaited(_restorePortraitChrome());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final source = sampleVideos[_currentVideoIndex];
      await _controller.initialize(
        source: source.toSource(),
        subtitles: source.subtitles,
        selectedSubtitleId: source.subtitles.isEmpty
            ? null
            : source.subtitles.first.id,
      );
      _controller.startQoeSampling(interval: const Duration(seconds: 5));
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _selectVideo(int index) async {
    if (_switching || index == _currentVideoIndex) {
      return;
    }
    setState(() {
      _currentVideoIndex = index;
      _switching = true;
      _latestCacheEvent = null;
      _handledCompletion = false;
    });
    try {
      await _cancelPrecacheTask();
      final source = sampleVideos[index];
      await _controller.setSource(
        source.toSource(),
        subtitles: source.subtitles,
        selectedSubtitleId: source.subtitles.isEmpty
            ? null
            : source.subtitles.first.id,
        autoPlay: true,
      );
      _qoeSnapshots.clear();
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
        });
      }
    }
  }

  void _handlePlaybackValue(M3u8PlayerValue value) {
    if (!value.isCompleted) {
      _handledCompletion = false;
      return;
    }
    if (_handledCompletion || _switching || !value.isInitialized) {
      return;
    }
    _handledCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_advanceAfterCompletion());
      }
    });
  }

  Future<void> _advanceAfterCompletion() async {
    if (_loopMode == ExampleLoopMode.single) {
      await _controller.seekTo(Duration.zero);
      await _controller.play();
      return;
    }
    final hasNext = _currentVideoIndex < sampleVideos.length - 1;
    if (_loopMode == ExampleLoopMode.playlist) {
      await _selectVideo(hasNext ? _currentVideoIndex + 1 : 0);
      return;
    }
    if (_autoPlayNext && hasNext) {
      await _selectVideo(_currentVideoIndex + 1);
    }
  }

  void _handleQoeSnapshot(M3u8QoeSnapshot snapshot) {
    if (!mounted) {
      return;
    }
    setState(() {
      _qoeSnapshots.insert(0, snapshot);
      if (_qoeSnapshots.length > 6) {
        _qoeSnapshots.removeRange(6, _qoeSnapshots.length);
      }
    });
  }

  void _handleCacheEvent(M3u8CacheEvent event) {
    if (!mounted || event.taskId != _precacheTaskId) {
      return;
    }
    setState(() {
      _latestCacheEvent = event;
      if (event.type == M3u8CacheEventType.completed ||
          event.type == M3u8CacheEventType.cancelled ||
          event.type == M3u8CacheEventType.error) {
        _precacheTaskId = null;
      }
    });
  }

  Future<void> _precacheCurrentSource() async {
    if (_precacheTaskId != null) {
      return;
    }
    final source = sampleVideos[_currentVideoIndex];
    if (!source.supportsPrecache) {
      return;
    }
    final taskId = await M3u8PlayerCache.precache(
      source.toSource(),
      initialPosition: _controller.value.position,
      quality: _controller.value.selectedQuality,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _precacheTaskId = taskId;
      _latestCacheEvent = M3u8CacheEvent(
        taskId: taskId,
        url: source.url,
        type: M3u8CacheEventType.progress,
        position: _controller.value.position,
        startPosition: _controller.value.position,
        quality: _controller.value.selectedQuality,
      );
    });
  }

  void _setPlaybackSpeed(double speed) {
    if (!_controller.value.isInitialized) {
      return;
    }
    unawaited(_controller.setPlaybackSpeed(speed));
  }

  void _setAutoPlayNext(bool value) {
    setState(() {
      _autoPlayNext = value;
    });
  }

  void _setLoopMode(ExampleLoopMode mode) {
    setState(() {
      _loopMode = mode;
    });
  }

  Future<void> _cancelPrecacheTask() async {
    final taskId = _precacheTaskId;
    if (taskId == null) {
      return;
    }
    if (mounted) {
      setState(() {
        _precacheTaskId = null;
      });
    } else {
      _precacheTaskId = null;
    }
    await M3u8PlayerCache.cancelPrecache(taskId);
  }

  void _cancelPrecacheTaskSilently() {
    final taskId = _precacheTaskId;
    if (taskId == null) {
      return;
    }
    _precacheTaskId = null;
    unawaited(M3u8PlayerCache.cancelPrecache(taskId));
  }

  Future<void> _copyLatestQoeSnapshot() async {
    if (_qoeSnapshots.isEmpty) {
      return;
    }
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(
      ClipboardData(text: encoder.convert(_qoeSnapshots.first.toMap())),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_strings.qoeSnapshotCopied)));
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == ExampleLanguage.zh
          ? ExampleLanguage.en
          : ExampleLanguage.zh;
    });
  }

  Future<void> _enterFullscreen() async {
    if (_isFullscreen) {
      return;
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    setState(() {
      _isFullscreen = true;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreen() async {
    if (!_isFullscreen) {
      return;
    }
    setState(() {
      _isFullscreen = false;
    });
    await _restorePortraitChrome();
  }

  Future<void> _restorePortraitChrome() async {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return Scaffold(
      backgroundColor: _isFullscreen ? Colors.black : null,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(strings.appTitle),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Tooltip(
                    message: strings.languageButtonTooltip,
                    child: TextButton.icon(
                      onPressed: _toggleLanguage,
                      icon: const Icon(Icons.translate),
                      label: Text(strings.languageButtonLabel),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        left: !_isFullscreen,
        right: !_isFullscreen,
        child: ValueListenableBuilder<M3u8PlayerValue>(
          valueListenable: _controller,
          builder:
              (BuildContext context, M3u8PlayerValue value, Widget? child) {
                _handlePlaybackValue(value);
                final player = ExampleVideoScaffold(
                  controller: _controller,
                  value: value,
                  title: sampleVideos[_currentVideoIndex].localizedTitle(
                    _language,
                  ),
                  episodes: [
                    for (final video in sampleVideos)
                      video.localizedTitle(_language),
                  ],
                  currentEpisodeIndex: _currentVideoIndex,
                  sourceType: sampleVideos[_currentVideoIndex].sourceType,
                  strings: strings,
                  isFullscreen: _isFullscreen,
                  isBusy: _initializing || _switching,
                  isPrecacheRunning: _precacheTaskId != null,
                  precacheSupported:
                      sampleVideos[_currentVideoIndex].supportsPrecache,
                  autoPlayNext: _autoPlayNext,
                  loopMode: _loopMode,
                  onBack: _isFullscreen ? _exitFullscreen : null,
                  onEnterFullscreen: _enterFullscreen,
                  onExitFullscreen: _exitFullscreen,
                  onEpisodeSelected: _selectVideo,
                  onPrecache: _precacheCurrentSource,
                  onSpeedSelected: _setPlaybackSpeed,
                  onAutoPlayNextChanged: _setAutoPlayNext,
                  onLoopModeChanged: _setLoopMode,
                );
                if (_isFullscreen) {
                  return player;
                }
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    player,
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _PlaylistControls(
                            videos: sampleVideos,
                            currentIndex: _currentVideoIndex,
                            switching: _switching,
                            language: _language,
                            onSelected: _selectVideo,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          _CacheTaskControls(
                            event: _latestCacheEvent,
                            isRunning: _precacheTaskId != null,
                            isSupported: sampleVideos[_currentVideoIndex]
                                .supportsPrecache,
                            onPrecache: _precacheCurrentSource,
                            onCancel: _cancelPrecacheTask,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          _Controls(
                            controller: _controller,
                            value: value,
                            sourceType:
                                sampleVideos[_currentVideoIndex].sourceType,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          _PlaybackStats(value: value, strings: strings),
                          const SizedBox(height: 16),
                          _QoePanel(
                            snapshots: _qoeSnapshots,
                            onCopyLatest: _copyLatestQoeSnapshot,
                            strings: strings,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

class _PlaylistControls extends StatelessWidget {
  const _PlaylistControls({
    required this.videos,
    required this.currentIndex,
    required this.switching,
    required this.language,
    required this.onSelected,
    required this.strings,
  });

  final List<VideoSource> videos;
  final int currentIndex;
  final bool switching;
  final ExampleLanguage language;
  final ValueChanged<int> onSelected;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = !switching && currentIndex > 0;
    final canGoNext = !switching && currentIndex < videos.length - 1;
    return Row(
      children: [
        IconButton.outlined(
          tooltip: strings.previousVideoTooltip,
          onPressed: canGoPrevious ? () => onSelected(currentIndex - 1) : null,
          icon: const Icon(Icons.skip_previous),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey<int>(currentIndex),
            initialValue: currentIndex,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (var index = 0; index < videos.length; index += 1)
                DropdownMenuItem<int>(
                  value: index,
                  child: Text(
                    videos[index].localizedTitle(language),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: switching
                ? null
                : (int? index) {
                    if (index != null) {
                      onSelected(index);
                    }
                  },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: strings.nextVideoTooltip,
          onPressed: canGoNext ? () => onSelected(currentIndex + 1) : null,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}

class _CacheTaskControls extends StatelessWidget {
  const _CacheTaskControls({
    required this.event,
    required this.isRunning,
    required this.isSupported,
    required this.onPrecache,
    required this.onCancel,
    required this.strings,
  });

  final M3u8CacheEvent? event;
  final bool isRunning;
  final bool isSupported;
  final VoidCallback onPrecache;
  final VoidCallback onCancel;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton.outlined(
          tooltip: strings.precacheCurrentSourceTooltip,
          onPressed: isRunning || !isSupported ? null : onPrecache,
          icon: const Icon(Icons.download),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: strings.cancelPrecacheTooltip,
          onPressed: isRunning ? onCancel : null,
          icon: const Icon(Icons.cancel_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isSupported
                ? _cacheStatus(event, isRunning, strings)
                : strings.precacheUnsupported,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _cacheStatus(
    M3u8CacheEvent? event,
    bool isRunning,
    ExampleStrings strings,
  ) {
    if (event == null) {
      return strings.precacheIdle;
    }
    final percent = event.percent?.clamp(0.0, 100.0).round();
    final progress = event.position == null
        ? ''
        : ' ${formatDuration(event.position!)}';
    final suffix = percent == null ? progress : ' $percent%$progress';
    final quality = event.quality?.label;
    final qualitySuffix = quality == null ? '' : ' $quality';
    return switch (event.type) {
      M3u8CacheEventType.completed => strings.precacheComplete(qualitySuffix),
      M3u8CacheEventType.cancelled => strings.precacheCancelled,
      M3u8CacheEventType.error => strings.precacheFailed(
        event.error?.message ?? strings.unknown,
      ),
      M3u8CacheEventType.progress =>
        isRunning
            ? strings.precaching(qualitySuffix, suffix)
            : strings.precacheIdle,
    };
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.value,
    required this.sourceType,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final M3u8SourceType sourceType;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filled(
              tooltip: value.isPlaying
                  ? strings.pauseTooltip
                  : strings.playTooltip,
              onPressed: value.isInitialized
                  ? () {
                      if (value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    }
                  : null,
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: strings.seekBack10Tooltip,
              onPressed: value.isInitialized
                  ? () => controller.seekBy(const Duration(seconds: -10))
                  : null,
              icon: const Icon(Icons.replay_10),
            ),
            IconButton.outlined(
              tooltip: strings.seekForward10Tooltip,
              onPressed: value.isInitialized
                  ? () => controller.seekBy(const Duration(seconds: 10))
                  : null,
              icon: const Icon(Icons.forward_10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BufferedSeekBar(
                controller: controller,
                value: value,
                strings: strings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SpeedSelector(controller: controller, value: value),
        const SizedBox(height: 8),
        _VolumeControl(controller: controller, value: value, strings: strings),
        const SizedBox(height: 8),
        _QualitySelector(
          controller: controller,
          value: value,
          isSupported: sourceType != M3u8SourceType.progressive,
          strings: strings,
        ),
        const SizedBox(height: 8),
        _SubtitleSelector(
          controller: controller,
          value: value,
          strings: strings,
        ),
      ],
    );
  }
}

class _SubtitleSelector extends StatelessWidget {
  const _SubtitleSelector({
    required this.controller,
    required this.value,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final subtitles = value.availableSubtitles;
    return DropdownButtonFormField<String>(
      key: ValueKey<String>(value.selectedSubtitle?.id ?? 'off'),
      initialValue: value.selectedSubtitle?.id ?? 'off',
      isExpanded: true,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        labelText: strings.subtitlesLabel,
      ),
      items: [
        DropdownMenuItem<String>(
          value: 'off',
          child: Text(strings.subtitlesOffLabel),
        ),
        for (final subtitle in subtitles)
          DropdownMenuItem<String>(
            value: subtitle.id,
            child: Text(subtitle.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: value.isInitialized
          ? (String? subtitleId) {
              controller.setSubtitle(subtitleId == 'off' ? null : subtitleId);
            }
          : null,
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.controller,
    required this.value,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: value.isMuted ? strings.unmuteTooltip : strings.muteTooltip,
          onPressed: value.isInitialized
              ? () => controller.setMuted(!value.isMuted)
              : null,
          icon: Icon(
            value.isMuted || value.volume == 0
                ? Icons.volume_off
                : Icons.volume_up,
          ),
        ),
        Expanded(
          child: Slider(
            value: value.volume.clamp(0.0, 1.0),
            onChanged: value.isInitialized
                ? (double volume) {
                    controller.setVolume(volume);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.controller, required this.value});

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;

  static const List<double> _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<double>(
      segments: [
        for (final speed in _speeds)
          ButtonSegment<double>(value: speed, label: Text(speedLabel(speed))),
      ],
      selected: <double>{_nearestConfiguredSpeed(value.playbackSpeed)},
      onSelectionChanged: value.isInitialized
          ? (Set<double> speeds) {
              controller.setPlaybackSpeed(speeds.single);
            }
          : null,
      showSelectedIcon: false,
    );
  }

  double _nearestConfiguredSpeed(double speed) {
    return nearestSpeed(speed, _speeds);
  }
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({
    required this.controller,
    required this.value,
    required this.isSupported,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final bool isSupported;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final qualities = <M3u8Quality>[
      M3u8Quality.auto,
      ...value.availableQualities,
    ];
    return DropdownButtonFormField<String>(
      key: ValueKey<String>(value.selectedQuality.id),
      initialValue: value.selectedQuality.id,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final quality in qualities)
          DropdownMenuItem<String>(
            value: quality.id,
            child: Text(
              qualityLabel(quality, strings),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: value.isInitialized && isSupported
          ? (String? qualityId) {
              final quality = qualities.firstWhere(
                (item) => item.id == qualityId,
                orElse: () => M3u8Quality.auto,
              );
              controller.setQuality(quality);
            }
          : null,
    );
  }
}

class _PlaybackStats extends StatelessWidget {
  const _PlaybackStats({required this.value, required this.strings});

  final M3u8PlayerValue value;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final durationMs = value.duration.inMilliseconds;
    final bufferedPercent = durationMs <= 0
        ? 0
        : (value.bufferedPosition.inMilliseconds / durationMs * 100)
              .clamp(0, 100)
              .round();
    final reportedDiskCachePercent = value.diskCachePercent.clamp(0.0, 100.0);
    final estimatedDiskCachePercent = durationMs <= 0
        ? 0.0
        : (value.diskCachePosition.inMilliseconds / durationMs * 100).clamp(
            0.0,
            100.0,
          );
    final diskCachePercent =
        (reportedDiskCachePercent > 0
                ? reportedDiskCachePercent
                : estimatedDiskCachePercent)
            .round();
    final bufferAhead = value.bufferedPosition - value.position;
    return DefaultTextStyle(
      style: textTheme.bodyMedium!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${strings.positionLabel}: ${formatDuration(value.position)}'),
          Text('${strings.durationLabel}: ${formatDuration(value.duration)}'),
          Text(
            '${strings.playerBufferLabel}: '
            '${formatDuration(value.bufferedPosition)} / '
            '${formatDuration(value.duration)} ($bufferedPercent%)',
          ),
          Text(
            '${strings.diskCacheLabel}: '
            '${formatDuration(value.diskCacheStartPosition)} - '
            '${formatDuration(value.diskCachePosition)} / '
            '${formatDuration(value.duration)} ($diskCachePercent%)'
            '${value.isDiskCacheComplete ? strings.completeSuffix : ''}',
          ),
          Text(
            '${strings.bufferAheadLabel}: '
            '${formatDuration(positiveDuration(bufferAhead))}',
          ),
          Text(
            '${strings.startupLabel}: ${value.startupTime.inMilliseconds} ms',
          ),
          Text('${strings.rebuffersLabel}: ${value.rebufferCount}'),
          Text(
            '${strings.rebufferTimeLabel}: '
            '${value.rebufferDuration.inMilliseconds} ms',
          ),
          Text('${strings.droppedFramesLabel}: ${value.droppedFrames}'),
          Text(
            '${strings.playbackSpeedLabel}: '
            '${speedLabel(value.playbackSpeed)}',
          ),
          Text(
            '${strings.volumeLabel}: ${(value.volume * 100).round()}%'
            '${value.isMuted ? strings.mutedSuffix : ''}',
          ),
          Text('${strings.qualitySwitchesLabel}: ${value.qualitySwitchCount}'),
          Text('${strings.recoveryLabel}: ${value.recoveryCount}'),
          if (value.lastRecoveryReason.isNotEmpty)
            Text('${strings.lastRecoveryLabel}: ${value.lastRecoveryReason}'),
          Text(
            '${strings.videoBitrateLabel}: '
            '${_formatBitrate(value.videoBitrate, strings)}',
          ),
          Text(
            '${strings.observedBitrateLabel}: '
            '${_formatBitrate(value.observedBitrate, strings)}',
          ),
          Text(
            '${strings.sizeLabel}: '
            '${value.size.width.toInt()} x ${value.size.height.toInt()}',
          ),
        ],
      ),
    );
  }
}

class _QoePanel extends StatelessWidget {
  const _QoePanel({
    required this.snapshots,
    required this.onCopyLatest,
    required this.strings,
  });

  final List<M3u8QoeSnapshot> snapshots;
  final VoidCallback onCopyLatest;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final latest = snapshots.isEmpty ? null : snapshots.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.qoeSnapshotsTitle,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton.outlined(
              tooltip: strings.copyLatestQoeSnapshotTooltip,
              onPressed: latest == null ? null : onCopyLatest,
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        if (latest == null)
          Text(strings.qoeWaitingForFirstSample, style: textTheme.bodyMedium)
        else ...[
          Text(
            strings.latestQoeRebufferRatio(
              '${(latest.rebufferRatio * 100).toStringAsFixed(1)}%',
            ),
          ),
          Text(
            strings.qoeDeltas(
              rebufferCountDelta: latest.rebufferCountDelta,
              droppedFramesDelta: latest.droppedFramesDelta,
              recoveryCountDelta: latest.recoveryCountDelta,
              qualitySwitchCountDelta: latest.qualitySwitchCountDelta,
            ),
          ),
          Text(
            strings.qoeBitrate(
              _formatBitrate(latest.videoBitrate, strings),
              _formatBitrate(latest.observedBitrate, strings),
            ),
          ),
          const SizedBox(height: 8),
          for (final snapshot in snapshots.take(3))
            Text(
              '${snapshot.endedAt.toIso8601String()} '
              'r=${(snapshot.rebufferRatio * 100).toStringAsFixed(1)}% '
              'q=${snapshot.selectedQuality.label}',
              style: textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

String _formatBitrate(int bitrate, ExampleStrings strings) {
  if (bitrate <= 0) {
    return strings.unknown;
  }
  if (bitrate >= 1000 * 1000) {
    return '${(bitrate / (1000 * 1000)).toStringAsFixed(1)} Mbps';
  }
  return '${(bitrate / 1000).round()} Kbps';
}
