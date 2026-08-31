import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import '../../../shared/localization/example_strings.dart';
import '../../../shared/widgets/buffered_seek_bar.dart';
import '../../../shared/formatters.dart';
import '../data/drama_models.dart';
import 'drama_cover_image.dart';
import 'feed_episode_sheet.dart';

/// Independent notifiers keep small overlay changes local to their consumers.
class DramaPlaybackUiState {
  DramaPlaybackUiState({bool overlayVisible = true})
    : overlayVisible = ValueNotifier<bool>(overlayVisible),
      isScrubbing = ValueNotifier<bool>(false),
      scrubPosition = ValueNotifier<Duration?>(null),
      liked = ValueNotifier<bool>(false),
      speed = ValueNotifier<double>(1.0),
      speedMenuVisible = ValueNotifier<bool>(false);

  final ValueNotifier<bool> overlayVisible;
  final ValueNotifier<bool> isScrubbing;
  final ValueNotifier<Duration?> scrubPosition;
  final ValueNotifier<bool> liked;
  final ValueNotifier<double> speed;
  final ValueNotifier<bool> speedMenuVisible;

  void dispose() {
    overlayVisible.dispose();
    isScrubbing.dispose();
    scrubPosition.dispose();
    liked.dispose();
    speed.dispose();
    speedMenuVisible.dispose();
  }
}

class DramaPlaybackItem extends StatelessWidget {
  const DramaPlaybackItem({
    super.key,
    required this.episode,
    required this.episodes,
    required this.currentIndex,
    required this.controller,
    required this.isActive,
    required this.uiState,
    required this.onBack,
    required this.onPlayPause,
    required this.onEpisodeSelected,
    required this.onSpeedSelected,
    required this.onScrubbingChanged,
    required this.onScrubPositionChanged,
  });

  final DramaEpisode episode;
  final List<DramaEpisode> episodes;
  final int currentIndex;
  final M3u8PlayerController controller;
  final bool isActive;
  final DramaPlaybackUiState uiState;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onEpisodeSelected;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onScrubbingChanged;
  final ValueChanged<Duration?> onScrubPositionChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DramaVideoSurface(
          controller: controller,
          episode: episode,
          isActive: isActive,
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (uiState.speedMenuVisible.value) {
                uiState.speedMenuVisible.value = false;
                return;
              }
              onPlayPause();
            },
            child: const _DramaGradientOverlay(),
          ),
        ),
        ValueListenableBuilder<M3u8PlayerValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.hasError || (value.isInitialized && !value.isBuffering)) {
              return const SizedBox.shrink();
            }
            return const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        DramaPauseButton(
          controller: controller,
          overlayVisible: uiState.overlayVisible,
          onPressed: onPlayPause,
        ),
        ValueListenableBuilder<bool>(
          valueListenable: uiState.overlayVisible,
          builder: (context, visible, child) {
            if (!visible) {
              return const SizedBox.shrink();
            }
            return DramaPlaybackOverlay(
              episode: episode,
              episodes: episodes,
              currentIndex: currentIndex,
              controller: controller,
              uiState: uiState,
              onBack: onBack,
              onEpisodeSelected: onEpisodeSelected,
              onSpeedSelected: onSpeedSelected,
              onScrubbingChanged: onScrubbingChanged,
              onScrubPositionChanged: onScrubPositionChanged,
            );
          },
        ),
      ],
    );
  }
}

class DramaVideoSurface extends StatelessWidget {
  const DramaVideoSurface({
    super.key,
    required this.controller,
    required this.episode,
    required this.isActive,
  });

  final M3u8PlayerController controller;
  final DramaEpisode episode;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<M3u8PlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (isActive && value.isInitialized) {
          return M3u8Player(controller: controller, fit: BoxFit.cover);
        }
        return DramaCoverImage(
          url: episode.cover,
          fit: BoxFit.cover,
          semanticLabel: episode.seriesTitle,
        );
      },
    );
  }
}

class DramaPauseButton extends StatelessWidget {
  const DramaPauseButton({
    super.key,
    required this.controller,
    required this.overlayVisible,
    required this.onPressed,
  });

  final M3u8PlayerController controller;
  final ValueListenable<bool> overlayVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<M3u8PlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: overlayVisible,
          builder: (context, visible, child) {
            if (!visible || !value.isInitialized || value.isPlaying) {
              return const SizedBox.shrink();
            }
            return Center(
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 52,
                  padding: const EdgeInsets.all(14),
                  color: Colors.white,
                  tooltip: '播放',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: onPressed,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DramaPlaybackOverlay extends StatelessWidget {
  const DramaPlaybackOverlay({
    super.key,
    required this.episode,
    required this.episodes,
    required this.currentIndex,
    required this.controller,
    required this.uiState,
    required this.onBack,
    required this.onEpisodeSelected,
    required this.onSpeedSelected,
    required this.onScrubbingChanged,
    required this.onScrubPositionChanged,
  });

  final DramaEpisode episode;
  final List<DramaEpisode> episodes;
  final int currentIndex;
  final M3u8PlayerController controller;
  final DramaPlaybackUiState uiState;
  final VoidCallback onBack;
  final ValueChanged<int> onEpisodeSelected;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onScrubbingChanged;
  final ValueChanged<Duration?> onScrubPositionChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: MediaQuery.paddingOf(context).top,
          left: 8,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DramaRightRail(
                uiState: uiState,
                onSpeedSelected: onSpeedSelected,
              ),
              DramaBottomControls(
                episode: episode,
                episodes: episodes,
                currentIndex: currentIndex,
                controller: controller,
                uiState: uiState,
                onEpisodeSelected: onEpisodeSelected,
                onScrubbingChanged: onScrubbingChanged,
                onScrubPositionChanged: onScrubPositionChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DramaBottomControls extends StatelessWidget {
  const DramaBottomControls({
    super.key,
    required this.episode,
    required this.episodes,
    required this.currentIndex,
    required this.controller,
    required this.uiState,
    required this.onEpisodeSelected,
    required this.onScrubbingChanged,
    required this.onScrubPositionChanged,
  });

  final DramaEpisode episode;
  final List<DramaEpisode> episodes;
  final int currentIndex;
  final M3u8PlayerController controller;
  final DramaPlaybackUiState uiState;
  final ValueChanged<int> onEpisodeSelected;
  final ValueChanged<bool> onScrubbingChanged;
  final ValueChanged<Duration?> onScrubPositionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: uiState.isScrubbing,
            builder: (context, isScrubbing, child) {
              if (isScrubbing) {
                return const SizedBox.shrink();
              }
              return _DramaEpisodeInfo(
                episode: episode,
                episodes: episodes,
                currentIndex: currentIndex,
                onEpisodeSelected: onEpisodeSelected,
              );
            },
          ),
          _DramaProgressControls(
            controller: controller,
            uiState: uiState,
            onScrubbingChanged: onScrubbingChanged,
            onScrubPositionChanged: onScrubPositionChanged,
          ),
        ],
      ),
    );
  }
}

class _DramaEpisodeInfo extends StatelessWidget {
  const _DramaEpisodeInfo({
    required this.episode,
    required this.episodes,
    required this.currentIndex,
    required this.onEpisodeSelected,
  });

  final DramaEpisode episode;
  final List<DramaEpisode> episodes;
  final int currentIndex;
  final ValueChanged<int> onEpisodeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          episode.seriesTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final series = DramaSeries(
              id: episode.seriesId,
              title: episode.seriesTitle,
              description: '',
              tags: const [],
              episodes: episodes,
            );
            final selected = await showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => FeedEpisodeSheet(
                series: series,
                episodes: episodes,
                currentIndex: currentIndex,
              ),
            );
            if (selected != null) {
              onEpisodeSelected(selected);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Drama · Ep. ${episode.number}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DramaProgressControls extends StatelessWidget {
  const _DramaProgressControls({
    required this.controller,
    required this.uiState,
    required this.onScrubbingChanged,
    required this.onScrubPositionChanged,
  });

  final M3u8PlayerController controller;
  final DramaPlaybackUiState uiState;
  final ValueChanged<bool> onScrubbingChanged;
  final ValueChanged<Duration?> onScrubPositionChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<M3u8PlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (!value.isInitialized) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: uiState.isScrubbing,
              builder: (context, isScrubbing, child) {
                if (!isScrubbing) {
                  return const SizedBox.shrink();
                }
                return ValueListenableBuilder<Duration?>(
                  valueListenable: uiState.scrubPosition,
                  builder: (context, scrubPosition, child) => Text(
                    '${formatDuration(scrubPosition ?? value.position)} / ${formatDuration(value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
            BufferedSeekBar(
              controller: controller,
              value: value,
              strings: const ExampleStrings(ExampleLanguage.zh),
              isOverlay: true,
              onScrubbingChanged: onScrubbingChanged,
              onScrubPositionChanged: onScrubPositionChanged,
            ),
          ],
        );
      },
    );
  }
}

class DramaRightRail extends StatelessWidget {
  const DramaRightRail({
    super.key,
    required this.uiState,
    required this.onSpeedSelected,
  });

  final DramaPlaybackUiState uiState;
  final ValueChanged<double> onSpeedSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: uiState.isScrubbing,
      builder: (context, isScrubbing, child) {
        if (isScrubbing) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<double>(
          valueListenable: uiState.speed,
          builder: (context, speed, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: uiState.liked,
              builder: (context, liked, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: uiState.speedMenuVisible,
                  builder: (context, speedMenuVisible, child) {
                    final width = speedMenuVisible ? 292.0 : 72.0;
                    return SizedBox(
                      width: width,
                      height: 140,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (speedMenuVisible)
                            Positioned(
                              left: 0,
                              width: 280,
                              bottom: 23,
                              child: _SpeedMenu(
                                selectedSpeed: speed,
                                onSelected: onSpeedSelected,
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            width: 72,
                            child: _RailActions(
                              liked: liked,
                              speed: speed,
                              onLike: () => uiState.liked.value = !liked,
                              onSpeedMenu: () =>
                                  uiState.speedMenuVisible.value =
                                      !speedMenuVisible,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RailActions extends StatelessWidget {
  const _RailActions({
    required this.liked,
    required this.speed,
    required this.onLike,
    required this.onSpeedMenu,
  });

  final bool liked;
  final double speed;
  final VoidCallback onLike;
  final VoidCallback onSpeedMenu;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onLike,
            icon: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.redAccent : Colors.white,
              size: 30,
            ),
          ),
          const Text(
            '728',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onSpeedMenu,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 32),
                const SizedBox(height: 4),
                Text(
                  '${speed}X',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.selectedSpeed, required this.onSelected});

  final double selectedSpeed;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ).copyWith(right: 40),
      decoration: BoxDecoration(
        color: const Color(0xff32252b),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final speed in [0.75, 1.0, 1.5, 2.0])
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(speed),
              child: Container(
                height: 33,
                width: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: speed == selectedSpeed
                      ? const Color(0xffe14c67)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${speed}X',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DramaGradientOverlay extends StatelessWidget {
  const _DramaGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.transparent,
              Colors.transparent,
              Colors.transparent,
              Colors.black,
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ),
        ),
      ),
    );
  }
}
