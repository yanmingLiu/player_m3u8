import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';

const String sampleM3u8Url =
    'https://prod-gg.niftyvaughanpxnew.com/movies/795bf902-1d7a-4811-af9e-239f0a232f3a-216100/index.m3u8';

const List<VideoSource> sampleVideos = <VideoSource>[
  VideoSource(title: 'Nifty VOD', url: sampleM3u8Url),
  VideoSource(
    title: 'Nifty VOD 292394',
    url:
        'https://prod-gg.niftyvaughanpxnew.com/movies/7b318dc9-64cb-49dd-bdc0-d28b80f6ed53-292394/index.m3u8',
  ),
  VideoSource(
    title: 'Nifty VOD 198867',
    url:
        'https://prod-gg.niftyvaughanpxnew.com/movies/b6cf4a77-6fa1-4b15-b5ec-f440b923c281-198867/index.m3u8',
  ),
  VideoSource(
    title: 'Mux HLS Test',
    url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  ),
  VideoSource(
    title: 'Tears of Steel',
    url:
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
  ),
  VideoSource(
    title: 'Apple BipBop',
    url:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8',
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

class PlayerM3u8ExampleApp extends StatelessWidget {
  const PlayerM3u8ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M3U8 Player',
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
  bool _initializing = true;
  bool _switching = false;
  int _currentVideoIndex = 0;
  String? _precacheTaskId;
  M3u8CacheEvent? _latestCacheEvent;

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
    ).showSnackBar(const SnackBar(content: Text('QoE snapshot copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('M3U8 Player')),
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
                    ),
                    const SizedBox(height: 16),
                    _CacheTaskControls(
                      event: _latestCacheEvent,
                      isRunning: _precacheTaskId != null,
                      onPrecache: _precacheCurrentSource,
                      onCancel: _cancelPrecacheTask,
                    ),
                    const SizedBox(height: 16),
                    _Controls(controller: _controller, value: value),
                    const SizedBox(height: 16),
                    _PlaybackStats(value: value),
                    const SizedBox(height: 16),
                    _QoePanel(
                      snapshots: _qoeSnapshots,
                      onCopyLatest: _copyLatestQoeSnapshot,
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
  });

  final List<VideoSource> videos;
  final int currentIndex;
  final bool switching;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = !switching && currentIndex > 0;
    final canGoNext = !switching && currentIndex < videos.length - 1;
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Previous video',
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
          tooltip: 'Next video',
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
  });

  final M3u8CacheEvent? event;
  final bool isRunning;
  final VoidCallback onPrecache;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Precache current source',
          onPressed: isRunning ? null : onPrecache,
          icon: const Icon(Icons.download),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Cancel precache',
          onPressed: isRunning ? onCancel : null,
          icon: const Icon(Icons.cancel_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _cacheStatus(event, isRunning),
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _cacheStatus(M3u8CacheEvent? event, bool isRunning) {
    if (event == null) {
      return 'Precache idle';
    }
    final percent = event.percent?.clamp(0.0, 100.0).round();
    final progress = event.position == null
        ? ''
        : ' ${_formatDuration(event.position!)}';
    final suffix = percent == null ? progress : ' $percent%$progress';
    final quality = event.quality?.label;
    final qualitySuffix = quality == null ? '' : ' $quality';
    return switch (event.type) {
      M3u8CacheEventType.completed => 'Precache complete$qualitySuffix',
      M3u8CacheEventType.cancelled => 'Precache cancelled',
      M3u8CacheEventType.error =>
        'Precache failed: ${event.error?.message ?? 'unknown'}',
      M3u8CacheEventType.progress =>
        isRunning ? 'Precaching$qualitySuffix$suffix' : 'Precache idle',
    };
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.value});

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filled(
              tooltip: value.isPlaying ? 'Pause' : 'Play',
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
              tooltip: 'Seek back 10 seconds',
              onPressed: value.isInitialized
                  ? () => controller.seekBy(const Duration(seconds: -10))
                  : null,
              icon: const Icon(Icons.replay_10),
            ),
            IconButton.outlined(
              tooltip: 'Seek forward 10 seconds',
              onPressed: value.isInitialized
                  ? () => controller.seekBy(const Duration(seconds: 10))
                  : null,
              icon: const Icon(Icons.forward_10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BufferedSeekBar(controller: controller, value: value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SpeedSelector(controller: controller, value: value),
        const SizedBox(height: 8),
        _VolumeControl(controller: controller, value: value),
        const SizedBox(height: 8),
        _QualitySelector(controller: controller, value: value),
      ],
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.controller, required this.value});

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: value.isMuted ? 'Unmute' : 'Mute',
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
  const _QualitySelector({required this.controller, required this.value});

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;

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
            child: Text(quality.label, overflow: TextOverflow.ellipsis),
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
  const _BufferedSeekBar({required this.controller, required this.value});

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;

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
              label: 'Playback progress',
              value:
                  '${_formatDuration(value.position)} of ${_formatDuration(value.duration)}',
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
  const _PlaybackStats({required this.value});

  final M3u8PlayerValue value;

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
          Text('Position: ${_formatDuration(value.position)}'),
          Text('Duration: ${_formatDuration(value.duration)}'),
          Text(
            'Player buffer: ${_formatDuration(value.bufferedPosition)} / '
            '${_formatDuration(value.duration)} ($bufferedPercent%)',
          ),
          Text(
            'Disk cache: ${_formatDuration(value.diskCacheStartPosition)} - '
            '${_formatDuration(value.diskCachePosition)} / '
            '${_formatDuration(value.duration)} ($diskCachePercent%)'
            '${value.isDiskCacheComplete ? ' complete' : ''}',
          ),
          Text(
            'Buffer ahead: ${_formatDuration(_positiveDuration(bufferAhead))}',
          ),
          Text('Startup: ${value.startupTime.inMilliseconds} ms'),
          Text('Rebuffers: ${value.rebufferCount}'),
          Text('Rebuffer time: ${value.rebufferDuration.inMilliseconds} ms'),
          Text('Dropped frames: ${value.droppedFrames}'),
          Text('Playback speed: ${_speedLabel(value.playbackSpeed)}'),
          Text(
            'Volume: ${(value.volume * 100).round()}%'
            '${value.isMuted ? ' muted' : ''}',
          ),
          Text('Quality switches: ${value.qualitySwitchCount}'),
          Text('Recovery: ${value.recoveryCount}'),
          if (value.lastRecoveryReason.isNotEmpty)
            Text('Last recovery: ${value.lastRecoveryReason}'),
          Text('Video bitrate: ${_formatBitrate(value.videoBitrate)}'),
          Text('Observed bitrate: ${_formatBitrate(value.observedBitrate)}'),
          Text(
            'Size: ${value.size.width.toInt()} x ${value.size.height.toInt()}',
          ),
        ],
      ),
    );
  }
}

class _QoePanel extends StatelessWidget {
  const _QoePanel({required this.snapshots, required this.onCopyLatest});

  final List<M3u8QoeSnapshot> snapshots;
  final VoidCallback onCopyLatest;

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
              child: Text('QoE snapshots', style: textTheme.titleMedium),
            ),
            IconButton.outlined(
              tooltip: 'Copy latest QoE snapshot',
              onPressed: latest == null ? null : onCopyLatest,
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        if (latest == null)
          Text('QoE waiting for first sample', style: textTheme.bodyMedium)
        else ...[
          Text(
            'Latest QoE: rebuffer ratio '
            '${(latest.rebufferRatio * 100).toStringAsFixed(1)}%',
          ),
          Text(
            'QoE deltas: rebuffer +${latest.rebufferCountDelta}, '
            'drop +${latest.droppedFramesDelta}, '
            'recover +${latest.recoveryCountDelta}, '
            'quality +${latest.qualitySwitchCountDelta}',
          ),
          Text(
            'QoE bitrate: ${_formatBitrate(latest.videoBitrate)} / '
            '${_formatBitrate(latest.observedBitrate)}',
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
  const _ErrorOverlay({required this.error, required this.onRetry});

  final M3u8PlayerError error;
  final VoidCallback onRetry;

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
                label: const Text('Retry'),
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

Duration _positiveDuration(Duration duration) {
  if (duration.isNegative) {
    return Duration.zero;
  }
  return duration;
}

String _formatBitrate(int bitrate) {
  if (bitrate <= 0) {
    return 'unknown';
  }
  if (bitrate >= 1000 * 1000) {
    return '${(bitrate / (1000 * 1000)).toStringAsFixed(1)} Mbps';
  }
  return '${(bitrate / 1000).round()} Kbps';
}
