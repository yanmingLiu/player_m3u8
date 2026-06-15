import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import 'buffered_seek_bar.dart';
import 'example_strings.dart';
import 'example_video_source.dart';
import 'player_formatters.dart';

class PlaylistControls extends StatelessWidget {
  const PlaylistControls({
    super.key,
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

class CacheTaskControls extends StatelessWidget {
  const CacheTaskControls({
    super.key,
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

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
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
        SpeedSelector(controller: controller, value: value),
        const SizedBox(height: 8),
        VolumeControl(controller: controller, value: value, strings: strings),
        const SizedBox(height: 8),
        QualitySelector(
          controller: controller,
          value: value,
          isSupported: sourceType != M3u8SourceType.progressive,
          strings: strings,
        ),
        const SizedBox(height: 8),
        SubtitleSelector(
          controller: controller,
          value: value,
          strings: strings,
        ),
      ],
    );
  }
}

class SubtitleSelector extends StatelessWidget {
  const SubtitleSelector({
    super.key,
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

class VolumeControl extends StatelessWidget {
  const VolumeControl({
    super.key,
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

class SpeedSelector extends StatelessWidget {
  const SpeedSelector({
    super.key,
    required this.controller,
    required this.value,
  });

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

class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
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

class PlaybackStats extends StatelessWidget {
  const PlaybackStats({super.key, required this.value, required this.strings});

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
            '${formatBitrate(value.videoBitrate, strings)}',
          ),
          Text(
            '${strings.observedBitrateLabel}: '
            '${formatBitrate(value.observedBitrate, strings)}',
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
