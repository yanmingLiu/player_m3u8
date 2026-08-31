import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../shared/localization/example_strings.dart';
import '../data/download_record_store.dart';
import '../data/video_source.dart';
import 'player_panels.dart';
import 'player_video_scaffold.dart';

// Cache orchestration is split from lifecycle/orientation code without
// exposing the page's private state as a public controller API.
part 'player_example_page_cache.dart';

typedef M3u8ControllerFactory = M3u8PlayerController Function();
typedef OrientationSetter =
    Future<void> Function(List<DeviceOrientation> orientations);
typedef SystemUiModeSetter = Future<void> Function(SystemUiMode mode);
typedef PhysicalOrientationStreamFactory =
    Stream<PhysicalDeviceOrientation> Function();

enum PhysicalDeviceOrientation { portrait, landscape }

class PlayerExamplePage extends StatefulWidget {
  const PlayerExamplePage({
    super.key,
    this.controllerFactory,
    this.autoInitialize = true,
    this.orientationSetter,
    this.systemUiModeSetter,
    this.physicalOrientationStreamFactory,
    this.visible = true,
    this.downloadRecordStore = const DownloadRecordStore(),
  });

  final M3u8ControllerFactory? controllerFactory;
  final bool autoInitialize;
  final OrientationSetter? orientationSetter;
  final SystemUiModeSetter? systemUiModeSetter;
  final PhysicalOrientationStreamFactory? physicalOrientationStreamFactory;
  final bool visible;
  final DownloadRecordStore downloadRecordStore;

  @override
  State<PlayerExamplePage> createState() => _PlayerExamplePageState();
}

class _PlayerExamplePageState extends State<PlayerExamplePage> {
  late final M3u8PlayerController _controller;
  late final DownloadRecordStore _downloadRecordStore;
  StreamSubscription<M3u8QoeSnapshot>? _qoeSubscription;
  StreamSubscription<M3u8CacheEvent>? _cacheSubscription;
  StreamSubscription<PhysicalDeviceOrientation>?
  _physicalOrientationSubscription;
  final List<M3u8QoeSnapshot> _qoeSnapshots = <M3u8QoeSnapshot>[];
  ExampleLanguage _language = ExampleLanguage.zh;
  bool _initializing = true;
  bool _switching = false;
  bool _isFullscreen = false;
  bool _fullscreenPinnedLandscape = false;
  bool _fullscreenEnteredManually = false;
  bool _fullscreenAwaitingLandscape = false;
  bool _fullscreenReachedLandscape = false;
  bool _fullscreenRotationGuardActive = false;
  bool _landscapeControlsLocked = false;
  bool _autoPlayNext = true;
  ExampleLoopMode _loopMode = ExampleLoopMode.none;
  Orientation? _lastLayoutOrientation;
  PhysicalDeviceOrientation? _lastPhysicalOrientation;
  bool _handledCompletion = false;
  int _currentVideoIndex = 0;
  String? _precacheTaskId;
  M3u8CacheEvent? _latestCacheEvent;
  M3u8CacheInfo? _cacheInfo;
  final Map<String, M3u8CacheTask> _cacheTasks = <String, M3u8CacheTask>{};
  final ValueNotifier<List<M3u8CacheTask>> _cacheTasksNotifier =
      ValueNotifier<List<M3u8CacheTask>>(const <M3u8CacheTask>[]);
  Timer? _downloadListRefreshTimer;
  Timer? _fullscreenRotationGuardTimer;
  M3u8CacheEvent? _latestDownloadEvent;
  bool? _lastConfiguredPlaybackActive;
  String? _lastReportedPlaybackErrorKey;
  String? _lastReportedCacheErrorKey;

  ExampleStrings get _strings => ExampleStrings(_language);

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerFactory?.call() ?? M3u8PlayerController();
    _downloadRecordStore = widget.downloadRecordStore;
    _qoeSubscription = _controller.qoeSnapshots.listen(_handleQoeSnapshot);
    _cacheSubscription = M3u8PlayerCache.events().listen(_handleCacheEvent);
    _physicalOrientationSubscription = _physicalOrientationStream().listen(
      _handlePhysicalOrientation,
    );
    if (widget.autoInitialize) {
      _initialize();
    } else {
      _initializing = false;
    }
  }

  @override
  void didUpdateWidget(covariant PlayerExamplePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible || !oldWidget.visible || !_controllerInitialized) {
      return;
    }
    unawaited(_controller.pause());
  }

  bool get _controllerInitialized => _controller.value.isInitialized;

  @override
  void dispose() {
    _qoeSubscription?.cancel();
    _cacheSubscription?.cancel();
    _physicalOrientationSubscription?.cancel();
    _downloadListRefreshTimer?.cancel();
    _fullscreenRotationGuardTimer?.cancel();
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

  Stream<PhysicalDeviceOrientation> _physicalOrientationStream() {
    final factory = widget.physicalOrientationStreamFactory;
    if (factory != null) {
      return factory().distinct();
    }
    return accelerometerEventStream(
          samplingPeriod: SensorInterval.normalInterval,
        )
        .map(_physicalOrientationFromAccelerometer)
        .where((orientation) => orientation != null)
        .cast<PhysicalDeviceOrientation>()
        .distinct();
  }

  PhysicalDeviceOrientation? _physicalOrientationFromAccelerometer(
    AccelerometerEvent event,
  ) {
    final horizontalGravity = event.x.abs();
    final verticalGravity = event.y.abs();
    const gravityThreshold = 6.5;
    const dominanceRatio = 1.25;
    if (horizontalGravity >= gravityThreshold &&
        horizontalGravity >= verticalGravity * dominanceRatio) {
      return PhysicalDeviceOrientation.landscape;
    }
    if (verticalGravity >= gravityThreshold &&
        verticalGravity >= horizontalGravity * dominanceRatio) {
      return PhysicalDeviceOrientation.portrait;
    }
    return null;
  }

  void _handlePhysicalOrientation(PhysicalDeviceOrientation orientation) {
    _lastPhysicalOrientation = orientation;
    if (!_isFullscreen || !mounted) {
      return;
    }
    if (orientation == PhysicalDeviceOrientation.landscape) {
      if (_fullscreenEnteredManually) {
        setState(() {
          _fullscreenEnteredManually = false;
          _fullscreenAwaitingLandscape = false;
          _fullscreenReachedLandscape = true;
          _fullscreenRotationGuardActive = false;
        });
        _fullscreenRotationGuardTimer?.cancel();
      }
      return;
    }
    if (orientation == PhysicalDeviceOrientation.portrait &&
        !_fullscreenEnteredManually &&
        !_fullscreenAwaitingLandscape &&
        !_fullscreenRotationGuardActive &&
        !_landscapeControlsLocked) {
      unawaited(_exitFullscreen());
    }
  }

  Future<void> _enterFullscreen({bool enteredByRotation = false}) async {
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
      _fullscreenPinnedLandscape = !enteredByRotation;
      _fullscreenEnteredManually = !enteredByRotation;
      _fullscreenAwaitingLandscape = !enteredByRotation;
      _fullscreenReachedLandscape = enteredByRotation;
      _fullscreenRotationGuardActive = !enteredByRotation;
    });
    await _setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (enteredByRotation) {
      await _applyOrientationPolicy();
      return;
    }
    await _setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startFullscreenRotationGuard();
    if (_lastPhysicalOrientation == PhysicalDeviceOrientation.landscape) {
      _handlePhysicalOrientation(PhysicalDeviceOrientation.landscape);
    }
  }

  Future<void> _exitFullscreen() async {
    if (!_isFullscreen) {
      return;
    }
    setState(() {
      _isFullscreen = false;
      _fullscreenPinnedLandscape = false;
      _fullscreenEnteredManually = false;
      _fullscreenAwaitingLandscape = false;
      _fullscreenReachedLandscape = false;
      _fullscreenRotationGuardActive = false;
      _landscapeControlsLocked = false;
    });
    await _restorePortraitChrome();
  }

  Future<void> _setLandscapeControlsLocked(bool locked) async {
    if (_landscapeControlsLocked == locked) {
      return;
    }
    setState(() {
      _landscapeControlsLocked = locked;
    });
    await _applyOrientationPolicy();
  }

  Future<void> _applyOrientationPolicy() async {
    if (_isFullscreen &&
        (_fullscreenPinnedLandscape || _landscapeControlsLocked)) {
      await _setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }
    await _setPreferredOrientations(const <DeviceOrientation>[]);
  }

  void _startFullscreenRotationGuard() {
    _fullscreenRotationGuardTimer?.cancel();
    _fullscreenRotationGuardTimer = Timer(
      const Duration(milliseconds: 1200),
      () {
        if (!mounted) {
          return;
        }
        setState(() {
          _fullscreenRotationGuardActive = false;
        });
      },
    );
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
    await _setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await _applyOrientationPolicy();
  }

  Future<void> _setPreferredOrientations(List<DeviceOrientation> orientations) {
    final setter = widget.orientationSetter;
    if (setter != null) {
      return setter(orientations);
    }
    return SystemChrome.setPreferredOrientations(orientations);
  }

  Future<void> _setEnabledSystemUIMode(SystemUiMode mode) {
    final setter = widget.systemUiModeSetter;
    if (setter != null) {
      return setter(mode);
    }
    return SystemChrome.setEnabledSystemUIMode(mode);
  }

  void _syncFullscreenWithOrientation(Orientation orientation) {
    final previousOrientation = _lastLayoutOrientation;
    _lastLayoutOrientation = orientation;
    if (previousOrientation == null || previousOrientation == orientation) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_isFullscreen && orientation == Orientation.landscape) {
        _fullscreenRotationGuardTimer?.cancel();
        setState(() {
          _fullscreenAwaitingLandscape = false;
          _fullscreenReachedLandscape = true;
          _fullscreenRotationGuardActive = false;
        });
        unawaited(_applyOrientationPolicy());
        return;
      }
      if (orientation == Orientation.landscape && !_isFullscreen) {
        unawaited(_enterFullscreen(enteredByRotation: true));
        return;
      }
      if (orientation == Orientation.portrait &&
          _isFullscreen &&
          !_fullscreenEnteredManually &&
          _fullscreenReachedLandscape &&
          !_fullscreenAwaitingLandscape &&
          !_fullscreenRotationGuardActive &&
          _lastPhysicalOrientation != PhysicalDeviceOrientation.landscape &&
          !_landscapeControlsLocked) {
        unawaited(_exitFullscreen());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final orientation = MediaQuery.orientationOf(context);
    _syncFullscreenWithOrientation(orientation);
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
                  controlsLocked: _landscapeControlsLocked,
                  isBusy: _initializing || _switching,
                  isPrecacheRunning: _precacheTaskId != null,
                  precacheSupported:
                      sampleVideos[_currentVideoIndex].supportsPrecache,
                  autoPlayNext: _autoPlayNext,
                  loopMode: _loopMode,
                  onBack: _isFullscreen ? _exitFullscreen : null,
                  onEnterFullscreen: _enterFullscreen,
                  onExitFullscreen: _exitFullscreen,
                  onControlsLockedChanged: (locked) =>
                      unawaited(_setLandscapeControlsLocked(locked)),
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
