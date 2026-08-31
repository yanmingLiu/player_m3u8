part of 'player_example_page.dart';

// This part shares the page's private state; setState is intentionally called
// here instead of exposing mutable cache state through a public API.
// ignore_for_file: invalid_use_of_protected_member

extension _PlayerExamplePageCache on _PlayerExamplePageState {
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
    final tasks = await _downloadRecordStore.restore();
    if (tasks.isEmpty) {
      return;
    }
    final restoredTasks = <String, M3u8CacheTask>{};
    for (final task in tasks) {
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
      return;
    }
    setState(() {
      _cacheTasks.addAll(restoredTasks);
      _syncCacheTasksNotifier();
    });
  }

  Future<void> _persistDownloadRecords() async {
    try {
      await _downloadRecordStore.save(
        _cacheTasks.values.where(
          (task) => task.owner == M3u8CacheTaskOwner.standalone,
        ),
      );
    } catch (_) {
      // Persistence is best-effort and must never interrupt playback.
    }
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
}
