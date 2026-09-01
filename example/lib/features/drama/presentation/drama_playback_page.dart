import 'dart:async';

import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import '../data/drama_models.dart';
import '../data/drama_progress_store.dart';
import 'drama_playback_widgets.dart';

class DramaPlaybackPage extends StatefulWidget {
  const DramaPlaybackPage({
    super.key,
    required this.episodes,
    this.seriesDescription = '',
    this.initialIndex = 0,
    this.progressStore = const DramaProgressStore(),
  });

  final List<DramaEpisode> episodes;
  final String seriesDescription;
  final int initialIndex;
  final DramaProgressStore progressStore;

  @override
  State<DramaPlaybackPage> createState() => _DramaPlaybackPageState();
}

class _DramaPlaybackPageState extends State<DramaPlaybackPage> {
  late final PageController _pages;
  late final DramaPlaybackUiState _uiState;
  late final M3u8PlayerController _controller;
  late final DramaProgressStore _progressStore;
  int _index = 0;
  int _sourceRequest = 0;
  Future<void> _sourceSwitchQueue = Future<void>.value();
  Timer? _saveTimer;
  StreamSubscription<M3u8CacheEvent>? _cacheSubscription;
  String? _precacheTaskId;
  int? _precacheIndex;
  bool _sourceSwitching = false;

  @override
  void initState() {
    super.initState();
    _index = widget.episodes.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.episodes.length - 1);
    _pages = PageController(initialPage: _index);
    _uiState = DramaPlaybackUiState();
    _controller = M3u8PlayerController();
    _progressStore = widget.progressStore;
    if (widget.episodes.isNotEmpty) {
      _listenForCacheEvents();
      unawaited(_initializeController());
      _saveTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_saveProgress()),
      );
    }
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize(source: _sourceFor(_index), autoPlay: true);
      unawaited(_precacheNext(_index));
    } catch (_) {
      // The player surface exposes the error state; avoid an unhandled
      // asynchronous exception during page construction.
    }
  }

  M3u8Source _sourceFor(int index) => M3u8Source(
    videoUrl: widget.episodes[index].video,
    sourceType: M3u8SourceType.progressive,
  );

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_saveProgress());
    _pages.dispose();
    _uiState.dispose();
    unawaited(_cacheSubscription?.cancel());
    unawaited(_cancelPrecache());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    if (_sourceSwitching ||
        widget.episodes.isEmpty ||
        _index >= widget.episodes.length) {
      return;
    }
    final episode = widget.episodes[_index];
    await _saveEpisodeProgress(episode, _controller.value.position);
  }

  Future<void> _saveEpisodeProgress(
    DramaEpisode episode,
    Duration position,
  ) async {
    try {
      await _progressStore.save(
        seriesId: episode.seriesId,
        episodeNumber: episode.number,
        position: position,
      );
    } catch (_) {
      // Progress persistence is best-effort and must not interrupt playback.
    }
  }

  void _showOverlay() => _uiState.overlayVisible.value = true;

  void _togglePlayback(M3u8PlayerController controller) {
    _showOverlay();
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else if (controller.isInitialized) {
      unawaited(controller.play());
    }
  }

  void _setScrubbing(bool scrubbing) {
    _uiState.isScrubbing.value = scrubbing;
    if (!scrubbing) {
      _uiState.scrubPosition.value = null;
    }
  }

  Future<void> _setSpeed(double speed) async {
    _uiState.speed.value = speed;
    _uiState.speedMenuVisible.value = false;
    _showOverlay();
    if (_controller.isInitialized) {
      await _controller.setPlaybackSpeed(speed);
    }
  }

  void _selectEpisode(int index) {
    if (index < 0 || index >= widget.episodes.length || index == _index) {
      return;
    }
    _pages.jumpToPage(index);
  }

  void _handlePageChanged(int index) {
    final previousIndex = _index;
    if (previousIndex < widget.episodes.length) {
      unawaited(
        _saveEpisodeProgress(
          widget.episodes[previousIndex],
          _controller.value.position,
        ),
      );
    }
    _sourceSwitching = true;
    setState(() => _index = index);
    _uiState.isScrubbing.value = false;
    _uiState.scrubPosition.value = null;
    final request = ++_sourceRequest;
    _sourceSwitchQueue = _sourceSwitchQueue.then((_) async {
      if (!mounted || request != _sourceRequest) {
        return;
      }
      try {
        await _controller.setSource(_sourceFor(index), autoPlay: true);
        await _precacheNext(index);
      } catch (_) {
        // A newer page change may supersede this request.
      } finally {
        if (mounted && request == _sourceRequest) {
          _sourceSwitching = false;
        }
      }
    });
    unawaited(_sourceSwitchQueue);
  }

  void _listenForCacheEvents() {
    try {
      _cacheSubscription = M3u8PlayerCache.events().listen((event) {
        if (event.taskId != _precacheTaskId || !event.isComplete) {
          return;
        }
        final completedIndex = _precacheIndex;
        _precacheTaskId = null;
        _precacheIndex = null;
        if (completedIndex != null) {
          unawaited(_precacheNext(completedIndex));
        }
      });
    } catch (_) {
      // Standalone cache is optional on a platform.
    }
  }

  Future<void> _precacheNext(int currentIndex) async {
    final nextIndex = currentIndex + 1;
    if (!mounted || nextIndex >= widget.episodes.length) {
      await _cancelPrecache();
      return;
    }
    if (_precacheIndex == nextIndex && _precacheTaskId != null) {
      return;
    }
    await _cancelPrecache();
    try {
      final taskId = await M3u8PlayerCache.precache(
        _sourceFor(nextIndex),
        priority: 10,
        metadata: <String, Object?>{'episodeIndex': nextIndex},
      );
      if (!mounted || _index != currentIndex) {
        await M3u8PlayerCache.cancelPrecache(taskId);
        return;
      }
      _precacheTaskId = taskId;
      _precacheIndex = nextIndex;
    } catch (_) {
      // Preloading is best-effort and must not block playback.
    }
  }

  Future<void> _cancelPrecache() async {
    final taskId = _precacheTaskId;
    _precacheTaskId = null;
    _precacheIndex = null;
    if (taskId == null) {
      return;
    }
    try {
      await M3u8PlayerCache.cancelPrecache(taskId);
    } catch (_) {
      // The task may have completed or been removed already.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('暂无剧集', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: widget.episodes.length,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, index) {
          return DramaPlaybackItem(
            episode: widget.episodes[index],
            episodes: widget.episodes,
            seriesDescription: widget.seriesDescription,
            currentIndex: _index,
            controller: _controller,
            isActive: index == _index,
            uiState: _uiState,
            onBack: () => Navigator.maybePop(context),
            onPlayPause: () => _togglePlayback(_controller),
            onEpisodeSelected: _selectEpisode,
            onSpeedSelected: _setSpeed,
            onScrubbingChanged: _setScrubbing,
            onScrubPositionChanged: (position) {
              _uiState.scrubPosition.value = position;
            },
          );
        },
      ),
    );
  }
}
