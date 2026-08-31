part of 'player_panels.dart';

class CacheMetricsPanel extends StatelessWidget {
  const CacheMetricsPanel({
    super.key,
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
            MetricChip(
              label: strings.cacheSizeLabel,
              value: cacheInfo == null
                  ? strings.unknown
                  : '${formatBytes(cacheInfo!.sizeBytes)} / '
                        '${formatBytes(cacheInfo!.maxSizeBytes)}',
            ),
            MetricChip(
              label: strings.diskCacheLabel,
              value: _playbackCacheProgress(),
            ),
            MetricChip(label: strings.runningTasksLabel, value: '$running'),
            MetricChip(label: strings.queuedTasksLabel, value: '$queued'),
            MetricChip(label: strings.failedTasksLabel, value: '$failed'),
            MetricChip(
              label: strings.downloadSpeedLabel,
              value: formatBytesPerSecond(
                activeTask?.downloadSpeedBytesPerSecond ??
                    event?.downloadSpeedBytesPerSecond ??
                    0,
              ),
            ),
            MetricChip(
              label: strings.bytesProgressLabel,
              value: _bytesProgress(activeTask, event),
            ),
            MetricChip(
              label: strings.cacheHitLabel,
              value:
                  '${activeTask?.cacheHitCount ?? event?.cacheHitCount ?? 0}',
            ),
            MetricChip(
              label: strings.networkFetchLabel,
              value:
                  '${activeTask?.networkFetchCount ?? event?.networkFetchCount ?? 0}',
            ),
            MetricChip(
              label: strings.segmentProgressLabel,
              value: _segmentProgress(activeTask, event),
            ),
            MetricChip(
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

class MetricChip extends StatelessWidget {
  const MetricChip({super.key, required this.label, required this.value});

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
                      return DownloadTaskTile(
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

class DownloadTaskTile extends StatelessWidget {
  const DownloadTaskTile({
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

class QoePanel extends StatelessWidget {
  const QoePanel({
    super.key,
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
              formatBitrate(latest.videoBitrate, strings),
              formatBitrate(latest.observedBitrate, strings),
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

String formatBitrate(int bitrate, ExampleStrings strings) {
  if (bitrate <= 0) {
    return strings.unknown;
  }
  if (bitrate >= 1000 * 1000) {
    return '${(bitrate / (1000 * 1000)).toStringAsFixed(1)} Mbps';
  }
  return '${(bitrate / 1000).round()} Kbps';
}
