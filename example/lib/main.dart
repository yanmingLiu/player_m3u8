import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';

const String sampleM3u8Url =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';

const List<VideoSource> sampleVideos = <VideoSource>[
  VideoSource(title: 'Apple BipBop', url: sampleM3u8Url),
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
];

void main() {
  runApp(const PlayerM3u8ExampleApp());
}

class VideoSource {
  const VideoSource({required this.title, required this.url});

  final String title;
  final String url;
}

enum ExampleLanguage { zh, en }

class ExampleStrings {
  const ExampleStrings(this.language);

  final ExampleLanguage language;

  bool get _isZh => language == ExampleLanguage.zh;

  String get appTitle => _isZh ? 'M3U8 播放器' : 'M3U8 Player';
  String get languageButtonLabel => _isZh ? 'EN' : '中文';
  String get languageButtonTooltip => _isZh ? '切换到英文' : 'Switch to Chinese';
  String get qoeSnapshotCopied => _isZh ? 'QoE 快照已复制' : 'QoE snapshot copied';
  String get previousVideoTooltip => _isZh ? '上一个视频' : 'Previous video';
  String get nextVideoTooltip => _isZh ? '下一个视频' : 'Next video';
  String get precacheCurrentSourceTooltip =>
      _isZh ? '预取当前播放源' : 'Precache current source';
  String get cancelPrecacheTooltip => _isZh ? '取消预取' : 'Cancel precache';
  String get precacheIdle => _isZh ? '预取空闲' : 'Precache idle';
  String get precacheCancelled => _isZh ? '预取已取消' : 'Precache cancelled';
  String get playTooltip => _isZh ? '播放' : 'Play';
  String get pauseTooltip => _isZh ? '暂停' : 'Pause';
  String get seekBack10Tooltip => _isZh ? '后退 10 秒' : 'Seek back 10 seconds';
  String get seekForward10Tooltip =>
      _isZh ? '前进 10 秒' : 'Seek forward 10 seconds';
  String get muteTooltip => _isZh ? '静音' : 'Mute';
  String get unmuteTooltip => _isZh ? '取消静音' : 'Unmute';
  String get playbackProgressSemantics => _isZh ? '播放进度' : 'Playback progress';
  String get positionLabel => _isZh ? '位置' : 'Position';
  String get durationLabel => _isZh ? '时长' : 'Duration';
  String get playerBufferLabel => _isZh ? '播放器缓冲' : 'Player buffer';
  String get diskCacheLabel => _isZh ? '磁盘缓存' : 'Disk cache';
  String get bufferAheadLabel => _isZh ? '前向缓冲' : 'Buffer ahead';
  String get startupLabel => _isZh ? '启动耗时' : 'Startup';
  String get rebuffersLabel => _isZh ? '卡顿次数' : 'Rebuffers';
  String get rebufferTimeLabel => _isZh ? '卡顿时长' : 'Rebuffer time';
  String get droppedFramesLabel => _isZh ? '丢帧' : 'Dropped frames';
  String get playbackSpeedLabel => _isZh ? '播放速度' : 'Playback speed';
  String get volumeLabel => _isZh ? '音量' : 'Volume';
  String get qualitySwitchesLabel => _isZh ? '清晰度切换' : 'Quality switches';
  String get recoveryLabel => _isZh ? '恢复次数' : 'Recovery';
  String get lastRecoveryLabel => _isZh ? '最近恢复' : 'Last recovery';
  String get videoBitrateLabel => _isZh ? '视频码率' : 'Video bitrate';
  String get observedBitrateLabel => _isZh ? '观测码率' : 'Observed bitrate';
  String get sizeLabel => _isZh ? '尺寸' : 'Size';
  String get completeSuffix => _isZh ? ' 完成' : ' complete';
  String get mutedSuffix => _isZh ? ' 静音' : ' muted';
  String get qoeSnapshotsTitle => _isZh ? 'QoE 快照' : 'QoE snapshots';
  String get copyLatestQoeSnapshotTooltip =>
      _isZh ? '复制最新 QoE 快照' : 'Copy latest QoE snapshot';
  String get qoeWaitingForFirstSample =>
      _isZh ? '等待首个 QoE 采样' : 'QoE waiting for first sample';
  String get retryLabel => _isZh ? '重试' : 'Retry';
  String get autoQualityLabel => _isZh ? '自动' : 'Auto';
  String get unknown => _isZh ? '未知' : 'unknown';

  String playbackProgressValue(Duration position, Duration duration) {
    if (_isZh) {
      return '${_formatDuration(position)} / ${_formatDuration(duration)}';
    }
    return '${_formatDuration(position)} of ${_formatDuration(duration)}';
  }

  String precacheComplete(String qualitySuffix) {
    return _isZh ? '预取完成$qualitySuffix' : 'Precache complete$qualitySuffix';
  }

  String precacheFailed(String error) {
    return _isZh ? '预取失败：$error' : 'Precache failed: $error';
  }

  String precaching(String qualitySuffix, String suffix) {
    return _isZh
        ? '正在预取$qualitySuffix$suffix'
        : 'Precaching$qualitySuffix$suffix';
  }

  String latestQoeRebufferRatio(String percent) {
    return _isZh
        ? '最新 QoE：卡顿占比 $percent'
        : 'Latest QoE: rebuffer ratio $percent';
  }

  String qoeDeltas({
    required int rebufferCountDelta,
    required int droppedFramesDelta,
    required int recoveryCountDelta,
    required int qualitySwitchCountDelta,
  }) {
    if (_isZh) {
      return 'QoE 增量：卡顿 +$rebufferCountDelta，'
          '丢帧 +$droppedFramesDelta，'
          '恢复 +$recoveryCountDelta，'
          '清晰度 +$qualitySwitchCountDelta';
    }
    return 'QoE deltas: rebuffer +$rebufferCountDelta, '
        'drop +$droppedFramesDelta, '
        'recover +$recoveryCountDelta, '
        'quality +$qualitySwitchCountDelta';
  }

  String qoeBitrate(String videoBitrate, String observedBitrate) {
    return _isZh
        ? 'QoE 码率：$videoBitrate / $observedBitrate'
        : 'QoE bitrate: $videoBitrate / $observedBitrate';
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize(sampleVideos[_currentVideoIndex].url);
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
    });
    try {
      await _cancelPrecacheTask();
      await _controller.setSource(sampleVideos[index].url, autoPlay: true);
      _qoeSnapshots.clear();
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
        });
      }
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
    final url = sampleVideos[_currentVideoIndex].url;
    final taskId = await M3u8PlayerCache.precache(
      url,
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
        url: url,
        type: M3u8CacheEventType.progress,
        position: _controller.value.position,
        startPosition: _controller.value.position,
        quality: _controller.value.selectedQuality,
      );
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

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return Scaffold(
      appBar: AppBar(
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
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<M3u8PlayerValue>(
          valueListenable: _controller,
          builder:
              (BuildContext context, M3u8PlayerValue value, Widget? child) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          M3u8Player(controller: _controller),
                          if (_initializing || _switching || value.isBuffering)
                            const Center(child: CircularProgressIndicator()),
                          if (value.hasError)
                            _ErrorOverlay(
                              error: value.error!,
                              onRetry: () => _controller.retry(autoPlay: true),
                              strings: strings,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PlaylistControls(
                      videos: sampleVideos,
                      currentIndex: _currentVideoIndex,
                      switching: _switching,
                      onSelected: _selectVideo,
                      strings: strings,
                    ),
                    const SizedBox(height: 16),
                    _CacheTaskControls(
                      event: _latestCacheEvent,
                      isRunning: _precacheTaskId != null,
                      onPrecache: _precacheCurrentSource,
                      onCancel: _cancelPrecacheTask,
                      strings: strings,
                    ),
                    const SizedBox(height: 16),
                    _Controls(
                      controller: _controller,
                      value: value,
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
    required this.onSelected,
    required this.strings,
  });

  final List<VideoSource> videos;
  final int currentIndex;
  final bool switching;
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
                    videos[index].title,
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
    required this.onPrecache,
    required this.onCancel,
    required this.strings,
  });

  final M3u8CacheEvent? event;
  final bool isRunning;
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
          onPressed: isRunning ? null : onPrecache,
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
            _cacheStatus(event, isRunning, strings),
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
        : ' ${_formatDuration(event.position!)}';
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
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
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
              child: _BufferedSeekBar(
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
          strings: strings,
        ),
      ],
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
          ButtonSegment<double>(value: speed, label: Text(_speedLabel(speed))),
      ],
      selected: <double>{_nearestSpeed(value.playbackSpeed)},
      onSelectionChanged: value.isInitialized
          ? (Set<double> speeds) {
              controller.setPlaybackSpeed(speeds.single);
            }
          : null,
      showSelectedIcon: false,
    );
  }

  double _nearestSpeed(double speed) {
    return _speeds.reduce((double previous, double next) {
      final previousDelta = (previous - speed).abs();
      final nextDelta = (next - speed).abs();
      return nextDelta < previousDelta ? next : previous;
    });
  }
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({
    required this.controller,
    required this.value,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
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
              _qualityLabel(quality, strings),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: value.isInitialized
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

class _BufferedSeekBar extends StatefulWidget {
  const _BufferedSeekBar({
    required this.controller,
    required this.value,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;

  @override
  State<_BufferedSeekBar> createState() => _BufferedSeekBarState();
}

class _BufferedSeekBarState extends State<_BufferedSeekBar> {
  bool _isScrubbing = false;
  double? _scrubFraction;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final durationMs = value.duration.inMilliseconds;
    final positionMs = durationMs == 0
        ? 0
        : value.position.inMilliseconds.clamp(0, durationMs);
    final bufferedMs = durationMs == 0
        ? 0
        : value.visibleBufferedPosition.inMilliseconds.clamp(0, durationMs);
    final bufferedStartMs = durationMs == 0
        ? 0
        : value.visibleBufferedStartPosition.inMilliseconds.clamp(
            0,
            bufferedMs,
          );
    final enabled = value.isInitialized && durationMs > 0;
    final playedFraction = durationMs == 0
        ? 0.0
        : (_scrubFraction ?? positionMs / durationMs);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      height: _isScrubbing ? 48 : 36,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled
                ? (TapDownDetails details) {
                    _seekFromDx(details.localPosition.dx, constraints.maxWidth);
                  }
                : null,
            onHorizontalDragStart: enabled
                ? (DragStartDetails details) {
                    _beginScrub(details.localPosition.dx, constraints.maxWidth);
                  }
                : null,
            onHorizontalDragUpdate: enabled
                ? (DragUpdateDetails details) {
                    _updateScrub(
                      details.localPosition.dx,
                      constraints.maxWidth,
                    );
                  }
                : null,
            onHorizontalDragEnd: enabled ? (_) => _endScrub() : null,
            onHorizontalDragCancel: enabled ? _cancelScrub : null,
            child: Semantics(
              label: widget.strings.playbackProgressSemantics,
              value: widget.strings.playbackProgressValue(
                value.position,
                value.duration,
              ),
              child: CustomPaint(
                painter: _BufferedTrackPainter(
                  playedFraction: playedFraction,
                  bufferedStartFraction: durationMs == 0
                      ? 0
                      : bufferedStartMs / durationMs,
                  bufferedFraction: durationMs == 0
                      ? 0
                      : bufferedMs / durationMs,
                  isScrubbing: _isScrubbing,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _beginScrub(double dx, double width) {
    setState(() {
      _isScrubbing = true;
      _scrubFraction = _fractionForDx(dx, width);
    });
  }

  void _updateScrub(double dx, double width) {
    final fraction = _fractionForDx(dx, width);
    setState(() {
      _scrubFraction = fraction;
    });
  }

  void _endScrub() {
    if (!_isScrubbing) {
      return;
    }
    final fraction = _scrubFraction;
    setState(() {
      _isScrubbing = false;
      _scrubFraction = null;
    });
    _seekToFraction(fraction);
  }

  void _cancelScrub() {
    if (!_isScrubbing) {
      return;
    }
    setState(() {
      _isScrubbing = false;
      _scrubFraction = null;
    });
  }

  void _seekFromDx(double dx, double width) {
    final fraction = _fractionForDx(dx, width);
    _seekToFraction(fraction);
  }

  double _fractionForDx(double dx, double width) {
    if (width <= 0) {
      return 0;
    }
    return (dx / width).clamp(0.0, 1.0);
  }

  void _seekToFraction(double? fraction) {
    final durationMs = widget.value.duration.inMilliseconds;
    if (fraction == null || durationMs <= 0) {
      return;
    }
    widget.controller.seekTo(
      Duration(milliseconds: (durationMs * fraction).round()),
    );
  }
}

class _BufferedTrackPainter extends CustomPainter {
  const _BufferedTrackPainter({
    required this.playedFraction,
    required this.bufferedStartFraction,
    required this.bufferedFraction,
    required this.isScrubbing,
  });

  final double playedFraction;
  final double bufferedStartFraction;
  final double bufferedFraction;
  final bool isScrubbing;

  @override
  void paint(Canvas canvas, Size size) {
    final baseHeight = isScrubbing ? 7.0 : 4.0;
    final bufferedHeight = isScrubbing ? 9.0 : 6.0;
    final playedHeight = isScrubbing ? 12.0 : 7.0;
    final centerY = size.height / 2;
    final baseRect = Rect.fromLTWH(
      0,
      centerY - baseHeight / 2,
      size.width,
      baseHeight,
    );
    final bufferedRect = Rect.fromLTWH(
      0,
      centerY - bufferedHeight / 2,
      size.width,
      bufferedHeight,
    );
    final playedRect = Rect.fromLTWH(
      0,
      centerY - playedHeight / 2,
      size.width,
      playedHeight,
    );

    void drawSegment({
      required Rect rect,
      double startFraction = 0,
      required double fraction,
      required Color color,
    }) {
      final start = startFraction.clamp(0.0, 1.0).toDouble();
      final end = fraction.clamp(start, 1.0).toDouble();
      final left = rect.left + rect.width * start;
      final width = rect.width * (end - start);
      if (width <= 0) {
        return;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, rect.top, width, rect.height),
          Radius.circular(rect.height / 2),
        ),
        Paint()..color = color,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, Radius.circular(baseRect.height / 2)),
      Paint()..color = const Color(0xFFD6DDD9),
    );
    drawSegment(
      rect: bufferedRect,
      startFraction: bufferedStartFraction,
      fraction: bufferedFraction,
      color: const Color(0xFFFFB74D),
    );
    drawSegment(
      rect: playedRect,
      fraction: playedFraction,
      color: const Color(0xFF006B5F),
    );

    final markerX = size.width * playedFraction.clamp(0.0, 1.0);
    if (!isScrubbing) {
      return;
    }
    canvas.drawCircle(
      Offset(markerX, centerY),
      10,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      Offset(markerX, centerY),
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF006B5F),
    );
  }

  @override
  bool shouldRepaint(covariant _BufferedTrackPainter oldDelegate) {
    return oldDelegate.playedFraction != playedFraction ||
        oldDelegate.bufferedStartFraction != bufferedStartFraction ||
        oldDelegate.bufferedFraction != bufferedFraction ||
        oldDelegate.isScrubbing != isScrubbing;
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
          Text('${strings.positionLabel}: ${_formatDuration(value.position)}'),
          Text('${strings.durationLabel}: ${_formatDuration(value.duration)}'),
          Text(
            '${strings.playerBufferLabel}: '
            '${_formatDuration(value.bufferedPosition)} / '
            '${_formatDuration(value.duration)} ($bufferedPercent%)',
          ),
          Text(
            '${strings.diskCacheLabel}: '
            '${_formatDuration(value.diskCacheStartPosition)} - '
            '${_formatDuration(value.diskCachePosition)} / '
            '${_formatDuration(value.duration)} ($diskCachePercent%)'
            '${value.isDiskCacheComplete ? strings.completeSuffix : ''}',
          ),
          Text(
            '${strings.bufferAheadLabel}: '
            '${_formatDuration(_positiveDuration(bufferAhead))}',
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
            '${_speedLabel(value.playbackSpeed)}',
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

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.error,
    required this.onRetry,
    required this.strings,
  });

  final M3u8PlayerError error;
  final VoidCallback onRetry;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.message,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(strings.retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _speedLabel(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.toStringAsFixed(0)}x';
  }
  return '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
}

String _qualityLabel(M3u8Quality quality, ExampleStrings strings) {
  if (quality.id == M3u8Quality.auto.id) {
    return strings.autoQualityLabel;
  }
  return quality.label;
}

Duration _positiveDuration(Duration duration) {
  if (duration.isNegative) {
    return Duration.zero;
  }
  return duration;
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
