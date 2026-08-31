import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import '../../../shared/localization/example_strings.dart';
import '../../../shared/widgets/buffered_seek_bar.dart';
import '../data/video_source.dart';
import '../../../shared/formatters.dart';

// Cache/download panels share the same player presentation library but live in
// their own file so the playback controls remain easy to scan.
part 'player_cache_panels.dart';

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
