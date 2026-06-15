import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/example_panels.dart';
import 'src/example_strings.dart';
import 'src/example_video_source.dart';
import 'src/video_scaffold.dart';

const String _downloadRecordsPreferenceKey =
    'player_m3u8_example_download_records';

void main() {
  runApp(const PlayerM3u8ExampleApp());
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
  String? _lastReportedPlaybackErrorKey;
  String? _lastReportedCacheErrorKey;

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
    } catch (error) {
      _showActionError(error);
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
    } catch (error) {
      _showActionError(error);
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
    _reportPlaybackError(value.error);
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
        unawaited(_runExampleAction(_advanceAfterCompletion));
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
    if (event.type == M3u8CacheEventType.error) {
      _reportCacheError(event);
    }
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
          unawaited(_runExampleAction(() => _playDownloadedTask(task)));
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
    } catch (error) {
      _showActionError(error);
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
        _showActionError(error);
        return;
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
    unawaited(_runExampleAction(() => _controller.setPlaybackSpeed(speed)));
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
    await _runExampleAction(() => M3u8PlayerCache.cancelPrecache(taskId));
  }

  void _cancelPrecacheTaskSilently() {
    final taskId = _precacheTaskId;
    if (taskId == null) {
      return;
    }
    _precacheTaskId = null;
    unawaited(M3u8PlayerCache.cancelPrecache(taskId));
  }

  Future<void> _runExampleAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _showActionError(error);
    }
  }

  void _reportPlaybackError(M3u8PlayerError? error) {
    if (error == null) {
      _lastReportedPlaybackErrorKey = null;
      return;
    }
    final key = '${error.code}:${error.message}:${error.details}';
    if (_lastReportedPlaybackErrorKey == key) {
      return;
    }
    _lastReportedPlaybackErrorKey = key;
    _showErrorSnackBar(_strings.playbackErrorTitle, error.message);
  }

  void _reportCacheError(M3u8CacheEvent event) {
    final error = event.error;
    if (error == null) {
      return;
    }
    final key = '${event.taskId}:${error.code}:${error.message}';
    if (_lastReportedCacheErrorKey == key) {
      return;
    }
    _lastReportedCacheErrorKey = key;
    _showErrorSnackBar(_strings.cacheErrorTitle, error.message);
  }

  void _showActionError(Object error) {
    _showErrorSnackBar(_strings.actionErrorTitle, error.toString());
  }

  void _showErrorSnackBar(String title, String message) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
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
                  onPrecache: () => _runExampleAction(_precacheCurrentSource),
                  onShowDownloads: () => _runExampleAction(_showDownloadList),
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
                          PlaylistControls(
                            videos: sampleVideos,
                            currentIndex: _currentVideoIndex,
                            switching: _switching,
                            language: _language,
                            onSelected: _selectVideo,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          CacheTaskControls(
                            event: _latestCacheEvent,
                            isRunning: _precacheTaskId != null,
                            isSupported: sampleVideos[_currentVideoIndex]
                                .supportsPrecache,
                            onPrecache: () =>
                                _runExampleAction(_precacheCurrentSource),
                            onCancel: _cancelPrecacheTask,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          PlaybackControls(
                            controller: _controller,
                            value: value,
                            sourceType:
                                sampleVideos[_currentVideoIndex].sourceType,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          PlaybackStats(value: value, strings: strings),
                          const SizedBox(height: 16),
                          CacheMetricsPanel(
                            value: value,
                            cacheInfo: _cacheInfo,
                            tasks: _cacheTasks.values.toList(growable: false),
                            latestEvent: _latestDownloadEvent,
                            strings: strings,
                          ),
                          const SizedBox(height: 16),
                          QoePanel(
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
