import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/buffered_seek_bar.dart';
import 'src/example_strings.dart';
import 'src/player_formatters.dart';
import 'src/video_scaffold.dart';

const String sampleM3u8Url =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
const String _downloadRecordsPreferenceKey =
    'player_m3u8_example_download_records';

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
  M3u8CacheInfo? _cacheInfo;
  final Map<String, M3u8CacheTask> _cacheTasks = <String, M3u8CacheTask>{};
  final ValueNotifier<List<M3u8CacheTask>> _cacheTasksNotifier =
      ValueNotifier<List<M3u8CacheTask>>(const <M3u8CacheTask>[]);
  Timer? _downloadListRefreshTimer;
  M3u8CacheEvent? _latestDownloadEvent;
  bool? _lastConfiguredPlaybackActive;

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
    _downloadListRefreshTimer?.cancel();
    _cacheTasksNotifier.dispose();
    _cancelPrecacheTaskSilently();
    unawaited(_restorePortraitChrome());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final source = sampleVideos[_currentVideoIndex];
      await _restoreDownloadRecords();
      await _configureDownloadConcurrency(playbackActive: false);
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
      unawaited(
        _configureDownloadConcurrency(
          playbackActive: _controller.value.isPlaying,
        ),
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
    unawaited(_configureDownloadConcurrency(playbackActive: value.isPlaying));
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
    if (!mounted) {
      return;
    }
    if (event.taskId.isEmpty) {
      return;
    }
    setState(() {
      if (event.taskId == _precacheTaskId) {
        _latestCacheEvent = event;
        if (event.type == M3u8CacheEventType.completed ||
            event.type == M3u8CacheEventType.cancelled ||
            event.type == M3u8CacheEventType.error) {
          _precacheTaskId = null;
        }
      }
      final task = _taskFromCacheEvent(event);
      _cacheTasks[task.taskId] = task;
      _latestDownloadEvent = event;
      _syncCacheTasksNotifier();
    });
    unawaited(_refreshCacheRuntimeState());
  }

  Future<void> _precacheCurrentSource() async {
    if (_precacheTaskId != null) {
      return;
    }
    final source = sampleVideos[_currentVideoIndex];
    if (!source.supportsPrecache) {
      return;
    }
    final selectedQuality = _controller.value.selectedQuality;
    final metadata = {
      ...source.downloadMetadata(_language),
      'quality': selectedQuality.toMap(),
    };
    final existingTask = _findDownloadTaskForSource(source.toSource());
    if (existingTask != null) {
      setState(() {
        _precacheTaskId = _isTerminalTask(existingTask)
            ? null
            : existingTask.taskId;
        _latestCacheEvent = existingTask.event;
      });
      await _showDownloadList();
      return;
    }
    final sourceInfo = await M3u8PlayerCache.sourceInfo(source.toSource());
    if (sourceInfo.sizeBytes > 0) {
      final taskId = 'cached:${source.url.hashCode}';
      setState(() {
        _cacheTasks[taskId] = M3u8CacheTask(
          taskId: taskId,
          url: source.url,
          owner: M3u8CacheTaskOwner.standalone,
          status: M3u8CacheTaskStatus.completed,
          sourceType: source.sourceType,
          bytesCached: sourceInfo.sizeBytes,
          bytesTotal: sourceInfo.sizeBytes,
          metadata: metadata,
          updatedAt: DateTime.now(),
        );
        _syncCacheTasksNotifier();
      });
      unawaited(_persistDownloadRecords());
      await _showDownloadList();
      return;
    }
    final taskId = await M3u8PlayerCache.precache(
      source.toSource(),
      initialPosition: _controller.value.position,
      quality: selectedQuality,
      metadata: metadata,
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
        quality: selectedQuality,
        metadata: metadata,
      );
      _cacheTasks[taskId] = M3u8CacheTask(
        taskId: taskId,
        url: source.url,
        owner: M3u8CacheTaskOwner.standalone,
        status: M3u8CacheTaskStatus.queued,
        sourceType: source.sourceType,
        metadata: metadata,
        updatedAt: DateTime.now(),
      );
      _syncCacheTasksNotifier();
    });
    unawaited(_persistDownloadRecords());
    unawaited(_refreshCacheRuntimeState());
  }

  Future<void> _refreshCacheRuntimeState() async {
    try {
      final info = await M3u8PlayerCache.info();
      final tasks = await M3u8PlayerCache.tasks();
      if (!mounted) return;
      setState(() {
        _cacheInfo = info;
        final activeTaskIds = tasks.map((task) => task.taskId).toSet();
        _cacheTasks.removeWhere((taskId, task) {
          return !activeTaskIds.contains(taskId) && !_isTerminalTask(task);
        });
        for (final task in tasks) {
          _cacheTasks[task.taskId] = task;
        }
        _syncCacheTasksNotifier();
      });
      unawaited(_persistDownloadRecords());
    } catch (_) {
      // Runtime diagnostics should not interrupt playback.
    }
  }

  Future<void> _showDownloadList() async {
    await _refreshCacheRuntimeState();
    if (!mounted) return;
    _startDownloadListRefreshTimer();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DownloadListSheet(
        tasksListenable: _cacheTasksNotifier,
        strings: _strings,
        onPlay: (task) {
          Navigator.of(context).pop();
          unawaited(_playDownloadedTask(task));
        },
        onPause: (taskId) => _runCacheTaskAction(
          taskId,
          () => M3u8PlayerCache.pausePrecache(taskId),
          optimisticStatus: M3u8CacheTaskStatus.paused,
        ),
        onResume: (taskId) => _runCacheTaskAction(
          taskId,
          () => M3u8PlayerCache.resumePrecache(taskId),
          optimisticStatus: M3u8CacheTaskStatus.queued,
        ),
        onCancel: (taskId) => _runCacheTaskAction(
          taskId,
          () => M3u8PlayerCache.cancelPrecache(taskId),
          removeImmediately: true,
        ),
      ),
    );
    _stopDownloadListRefreshTimer();
    unawaited(_refreshCacheRuntimeState());
  }

  Future<void> _playDownloadedTask(M3u8CacheTask task) async {
    final source = _sourceFromDownloadTask(task);
    if (source == null) {
      return;
    }
    setState(() {
      _switching = true;
      _latestCacheEvent = null;
      _handledCompletion = false;
    });
    try {
      await _cancelPrecacheTask();
      await _controller.setSource(source, autoPlay: true);
      final quality = _qualityFromDownloadTask(task);
      if (quality != null && !quality.isAuto) {
        await _controller.setQuality(quality);
      }
      _qoeSnapshots.clear();
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
        });
      }
    }
  }

  M3u8Source? _sourceFromDownloadTask(M3u8CacheTask task) {
    final sourceMetadata = task.metadata['source'];
    if (sourceMetadata is Map) {
      final source = M3u8Source.fromMap(
        Map<Object?, Object?>.from(sourceMetadata),
      );
      if (source.videoUrl.isNotEmpty) {
        return source;
      }
    }
    if (task.url.isEmpty) {
      return null;
    }
    return M3u8Source(videoUrl: task.url, sourceType: task.sourceType);
  }

  M3u8Quality? _qualityFromDownloadTask(M3u8CacheTask task) {
    final quality = task.metadata['quality'];
    if (quality is! Map) {
      return null;
    }
    return M3u8Quality.fromMap(Map<Object?, Object?>.from(quality));
  }

  M3u8CacheTask _taskFromCacheEvent(M3u8CacheEvent event) {
    return M3u8CacheTask.fromMap({
      'taskId': event.taskId,
      'url': event.url,
      'owner': event.owner.name,
      'status': event.status.name,
      'sourceType': event.sourceType.platformValue,
      'priority': event.priority,
      'bytesCached': event.bytesCached,
      'bytesTotal': event.bytesTotal,
      'downloadSpeedBytesPerSecond': event.downloadSpeedBytesPerSecond,
      'cacheHitCount': event.cacheHitCount,
      'networkFetchCount': event.networkFetchCount,
      'segmentIndex': event.segmentIndex,
      'segmentCount': event.segmentCount,
      'currentUrl': event.currentUrl,
      'retryCount': event.retryCount,
      'updatedAt': event.updatedAt?.millisecondsSinceEpoch,
      'metadata': event.metadata,
      'event': event.type.name,
      'diskCachePercent': event.percent,
      'quality': event.quality?.toMap(),
    });
  }

  Future<void> _runCacheTaskAction(
    String taskId,
    Future<void> Function() action, {
    bool removeImmediately = false,
    M3u8CacheTaskStatus? optimisticStatus,
  }) async {
    if (removeImmediately && mounted) {
      setState(() {
        _removeCacheTask(taskId);
      });
    } else if (optimisticStatus != null && mounted) {
      setState(() {
        _updateCacheTaskStatus(taskId, optimisticStatus);
      });
    }
    try {
      await action();
      await _refreshCacheRuntimeState();
    } catch (error) {
      if (!error.toString().contains('unknown_cache_task')) {
        rethrow;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _removeCacheTask(taskId);
      });
    } finally {
      unawaited(_persistDownloadRecords());
      unawaited(_refreshCacheRuntimeState());
    }
  }

  void _removeCacheTask(String taskId) {
    _cacheTasks.remove(taskId);
    if (_precacheTaskId == taskId) {
      _precacheTaskId = null;
    }
    _syncCacheTasksNotifier();
  }

  void _updateCacheTaskStatus(String taskId, M3u8CacheTaskStatus status) {
    final task = _cacheTasks[taskId];
    if (task == null) {
      return;
    }
    _cacheTasks[taskId] = task.copyWith(
      status: status,
      downloadSpeedBytesPerSecond: status == M3u8CacheTaskStatus.paused
          ? 0
          : task.downloadSpeedBytesPerSecond,
      updatedAt: DateTime.now(),
    );
    _syncCacheTasksNotifier();
  }

  void _syncCacheTasksNotifier() {
    _cacheTasksNotifier.value = _sortedCacheTasks();
  }

  List<M3u8CacheTask> _sortedCacheTasks() {
    return _cacheTasks.values.toList(growable: false)..sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  }

  bool _isTerminalTask(M3u8CacheTask task) {
    return task.status == M3u8CacheTaskStatus.completed ||
        task.status == M3u8CacheTaskStatus.cancelled ||
        task.status == M3u8CacheTaskStatus.error;
  }

  Future<void> _restoreDownloadRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final values =
        preferences.getStringList(_downloadRecordsPreferenceKey) ??
        const <String>[];
    if (values.isEmpty) {
      return;
    }
    final restoredTasks = <String, M3u8CacheTask>{};
    for (final value in values) {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        continue;
      }
      final task = M3u8CacheTask.fromMap(Map<Object?, Object?>.from(decoded));
      if (task.taskId.isEmpty) {
        continue;
      }
      if (task.status == M3u8CacheTaskStatus.completed) {
        final source = _sourceFromDownloadTask(task);
        if (source == null) {
          continue;
        }
        final info = await M3u8PlayerCache.sourceInfo(source);
        if (info.sizeBytes <= 0) {
          continue;
        }
      }
      restoredTasks[task.taskId] = task;
    }
    if (restoredTasks.isEmpty) {
      return;
    }
    if (!mounted) {
      _cacheTasks.addAll(restoredTasks);
      _syncCacheTasksNotifier();
      return;
    }
    setState(() {
      _cacheTasks.addAll(restoredTasks);
      _syncCacheTasksNotifier();
    });
  }

  Future<void> _persistDownloadRecords() async {
    final records = _cacheTasks.values
        .where((task) => task.owner == M3u8CacheTaskOwner.standalone)
        .map(_downloadRecordToJson)
        .toList(growable: false);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_downloadRecordsPreferenceKey, records);
  }

  String _downloadRecordToJson(M3u8CacheTask task) {
    return jsonEncode({
      'taskId': task.taskId,
      'url': task.url,
      'owner': task.owner.name,
      'status': task.status.name,
      'sourceType': task.sourceType.platformValue,
      'priority': task.priority,
      'bytesCached': task.bytesCached,
      'bytesTotal': task.bytesTotal,
      'downloadSpeedBytesPerSecond': task.downloadSpeedBytesPerSecond,
      'cacheHitCount': task.cacheHitCount,
      'networkFetchCount': task.networkFetchCount,
      'segmentIndex': task.segmentIndex,
      'segmentCount': task.segmentCount,
      'currentUrl': task.currentUrl,
      'retryCount': task.retryCount,
      'updatedAt': task.updatedAt?.millisecondsSinceEpoch,
      'metadata': task.metadata,
    });
  }

  M3u8CacheTask? _findDownloadTaskForSource(M3u8Source source) {
    for (final task in _cacheTasks.values) {
      final taskSource = _sourceFromDownloadTask(task);
      if (taskSource == source) {
        return task;
      }
    }
    return null;
  }

  Future<void> _configureDownloadConcurrency({
    required bool playbackActive,
  }) async {
    if (_lastConfiguredPlaybackActive == playbackActive) {
      return;
    }
    _lastConfiguredPlaybackActive = playbackActive;
    try {
      await M3u8PlayerCache.configure(
        maxConcurrentPrecacheTasks: playbackActive ? 1 : 2,
      );
    } catch (_) {
      // Cache policy changes are best-effort in the example UI.
    }
  }

  void _startDownloadListRefreshTimer() {
    _downloadListRefreshTimer?.cancel();
    _downloadListRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) {
        unawaited(_refreshCacheRuntimeState());
      },
    );
  }

  void _stopDownloadListRefreshTimer() {
    _downloadListRefreshTimer?.cancel();
    _downloadListRefreshTimer = null;
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
                  onShowDownloads: _showDownloadList,
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
                          _CacheMetricsPanel(
                            value: value,
                            cacheInfo: _cacheInfo,
                            tasks: _cacheTasks.values.toList(growable: false),
                            latestEvent: _latestDownloadEvent,
                            strings: strings,
                          ),
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

class _CacheMetricsPanel extends StatelessWidget {
  const _CacheMetricsPanel({
    required this.value,
    required this.cacheInfo,
    required this.tasks,
    required this.latestEvent,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final M3u8CacheInfo? cacheInfo;
  final List<M3u8CacheTask> tasks;
  final M3u8CacheEvent? latestEvent;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final running = tasks
        .where((task) => task.status == M3u8CacheTaskStatus.running)
        .length;
    final queued = tasks
        .where((task) => task.status == M3u8CacheTaskStatus.queued)
        .length;
    final failed = tasks
        .where((task) => task.status == M3u8CacheTaskStatus.error)
        .length;
    final activeTask = _activeDownloadTask();
    final event = latestEvent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.cacheMetricsTitle, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _MetricChip(
              label: strings.cacheSizeLabel,
              value: cacheInfo == null
                  ? strings.unknown
                  : '${formatBytes(cacheInfo!.sizeBytes)} / '
                        '${formatBytes(cacheInfo!.maxSizeBytes)}',
            ),
            _MetricChip(
              label: strings.diskCacheLabel,
              value: _playbackCacheProgress(),
            ),
            _MetricChip(label: strings.runningTasksLabel, value: '$running'),
            _MetricChip(label: strings.queuedTasksLabel, value: '$queued'),
            _MetricChip(label: strings.failedTasksLabel, value: '$failed'),
            _MetricChip(
              label: strings.downloadSpeedLabel,
              value: formatBytesPerSecond(
                activeTask?.downloadSpeedBytesPerSecond ??
                    event?.downloadSpeedBytesPerSecond ??
                    0,
              ),
            ),
            _MetricChip(
              label: strings.bytesProgressLabel,
              value: _bytesProgress(activeTask, event),
            ),
            _MetricChip(
              label: strings.cacheHitLabel,
              value:
                  '${activeTask?.cacheHitCount ?? event?.cacheHitCount ?? 0}',
            ),
            _MetricChip(
              label: strings.networkFetchLabel,
              value:
                  '${activeTask?.networkFetchCount ?? event?.networkFetchCount ?? 0}',
            ),
            _MetricChip(
              label: strings.segmentProgressLabel,
              value: _segmentProgress(activeTask, event),
            ),
            _MetricChip(
              label: strings.retryCountLabel,
              value: '${activeTask?.retryCount ?? event?.retryCount ?? 0}',
            ),
          ],
        ),
        if ((activeTask?.currentUrl ?? event?.currentUrl) != null) ...[
          const SizedBox(height: 8),
          Text(
            '${strings.currentDownloadUrlLabel}: '
            '${activeTask?.currentUrl ?? event?.currentUrl}',
            style: textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (event?.error != null)
          Text(
            strings.precacheFailed(event!.error!.message),
            style: textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
      ],
    );
  }

  String _bytesProgress(M3u8CacheTask? task, M3u8CacheEvent? event) {
    final cached = task?.bytesCached ?? event?.bytesCached ?? 0;
    final total = task?.bytesTotal ?? event?.bytesTotal ?? 0;
    return '${formatBytes(cached)} / ${formatBytes(total)}';
  }

  String _segmentProgress(M3u8CacheTask? task, M3u8CacheEvent? event) {
    final index = task?.segmentIndex ?? event?.segmentIndex ?? 0;
    final count = task?.segmentCount ?? event?.segmentCount ?? 0;
    if (count <= 0) {
      return '0 / 0';
    }
    return '${index + 1} / $count';
  }

  M3u8CacheTask? _activeDownloadTask() {
    for (final task in tasks) {
      if (task.status == M3u8CacheTaskStatus.running ||
          task.status == M3u8CacheTaskStatus.queued ||
          task.status == M3u8CacheTaskStatus.paused) {
        return task;
      }
    }
    return tasks.isEmpty ? null : tasks.first;
  }

  String _playbackCacheProgress() {
    final percent = value.diskCachePercent.clamp(0, 100).toStringAsFixed(0);
    final start = formatDuration(value.diskCacheStartPosition);
    final end = formatDuration(value.diskCachePosition);
    final duration = formatDuration(value.duration);
    final suffix = value.isDiskCacheComplete ? strings.completeSuffix : '';
    return '$start-$end / $duration ($percent%)$suffix';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text('$label: $value'),
      ),
    );
  }
}

class DownloadListSheet extends StatelessWidget {
  const DownloadListSheet({
    super.key,
    required this.tasksListenable,
    required this.strings,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final ValueListenable<List<M3u8CacheTask>> tasksListenable;
  final ExampleStrings strings;
  final ValueChanged<M3u8CacheTask> onPlay;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.downloadListTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: ValueListenableBuilder<List<M3u8CacheTask>>(
                valueListenable: tasksListenable,
                builder: (context, tasks, _) {
                  if (tasks.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(strings.noDownloadTasks),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _DownloadTaskTile(
                        key: ValueKey(task.taskId),
                        task: task,
                        strings: strings,
                        onPlay: onPlay,
                        onPause: onPause,
                        onResume: onResume,
                        onCancel: onCancel,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({
    super.key,
    required this.task,
    required this.strings,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final M3u8CacheTask task;
  final ExampleStrings strings;
  final ValueChanged<M3u8CacheTask> onPlay;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    final isStandalone = task.owner == M3u8CacheTaskOwner.standalone;
    final isActionable =
        isStandalone &&
        (task.status == M3u8CacheTaskStatus.queued ||
            task.status == M3u8CacheTaskStatus.running ||
            task.status == M3u8CacheTaskStatus.paused);
    final isPlayable =
        isStandalone && task.status == M3u8CacheTaskStatus.completed;
    final progress = task.bytesTotal > 0
        ? task.progress
        : ((task.event?.percent ?? 0) / 100).clamp(0.0, 1.0);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: isPlayable || isActionable,
      onTap: isPlayable ? () => onPlay(task) : null,
      title: Text(
        task.metadata['title'] as String? ?? task.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            '${_ownerLabel(task.owner)} · ${task.status.name} · '
            '${formatBytes(task.bytesCached)} / ${formatBytes(task.bytesTotal)} · '
            '${formatBytesPerSecond(task.downloadSpeedBytesPerSecond)}',
          ),
          Text(
            '${strings.segmentProgressLabel}: '
            '${task.segmentCount <= 0 ? 0 : task.segmentIndex + 1}/${task.segmentCount} · '
            '${strings.retryCountLabel}: ${task.retryCount}',
          ),
          if (task.currentUrl != null)
            Text(
              task.currentUrl!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: isActionable
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: task.status == M3u8CacheTaskStatus.paused
                      ? strings.resumeDownloadTooltip
                      : strings.pauseDownloadTooltip,
                  onPressed: () {
                    if (task.status == M3u8CacheTaskStatus.paused) {
                      onResume(task.taskId);
                    } else {
                      onPause(task.taskId);
                    }
                  },
                  icon: Icon(
                    task.status == M3u8CacheTaskStatus.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                  ),
                ),
                IconButton(
                  tooltip: strings.cancelDownloadTooltip,
                  onPressed: () => onCancel(task.taskId),
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : const Icon(Icons.lock_outline),
    );
  }

  String _ownerLabel(M3u8CacheTaskOwner owner) {
    return owner == M3u8CacheTaskOwner.player
        ? strings.playerOwnedTaskLabel
        : strings.standaloneTaskLabel;
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
