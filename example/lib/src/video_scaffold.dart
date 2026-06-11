import 'dart:async';

import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import 'buffered_seek_bar.dart';
import 'example_strings.dart';
import 'player_formatters.dart';

enum ExampleLoopMode { none, single, playlist }

class ExampleVideoScaffold extends StatefulWidget {
  const ExampleVideoScaffold({
    super.key,
    required this.controller,
    required this.value,
    required this.title,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.sourceType,
    required this.strings,
    required this.isFullscreen,
    required this.isBusy,
    required this.isPrecacheRunning,
    required this.precacheSupported,
    required this.autoPlayNext,
    required this.loopMode,
    required this.onBack,
    required this.onEnterFullscreen,
    required this.onExitFullscreen,
    required this.onEpisodeSelected,
    required this.onPrecache,
    required this.onSpeedSelected,
    required this.onAutoPlayNextChanged,
    required this.onLoopModeChanged,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final String title;
  final List<String> episodes;
  final int currentEpisodeIndex;
  final M3u8SourceType sourceType;
  final ExampleStrings strings;
  final bool isFullscreen;
  final bool isBusy;
  final bool isPrecacheRunning;
  final bool precacheSupported;
  final bool autoPlayNext;
  final ExampleLoopMode loopMode;
  final VoidCallback? onBack;
  final VoidCallback onEnterFullscreen;
  final VoidCallback onExitFullscreen;
  final ValueChanged<int> onEpisodeSelected;
  final VoidCallback onPrecache;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onAutoPlayNextChanged;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  @override
  State<ExampleVideoScaffold> createState() => _ExampleVideoScaffoldState();
}

class _ExampleVideoScaffoldState extends State<ExampleVideoScaffold> {
  static const Duration _overlayTimeout = Duration(seconds: 3);

  Timer? _overlayTimer;
  bool _controlsVisible = true;
  bool _optionSheetOpen = false;
  LandscapeSidePanelType? _sidePanel;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  @override
  void didUpdateWidget(covariant ExampleVideoScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFullscreen != oldWidget.isFullscreen ||
        widget.value.isPlaying != oldWidget.value.isPlaying ||
        widget.value.isBuffering != oldWidget.value.isBuffering ||
        widget.value.hasError != oldWidget.value.hasError) {
      _scheduleAutoHide();
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          M3u8Player(controller: widget.controller, fit: BoxFit.contain),
          if (widget.isBusy || widget.value.isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_controlsVisible && !widget.value.hasError)
            if (widget.isFullscreen && _sidePanel != null)
              _buildLandscapeSidePanel()
            else
              PlayerOverlayChrome(
                child: widget.isFullscreen
                    ? LandscapePlayerControls(
                        controller: widget.controller,
                        value: widget.value,
                        title: widget.title,
                        episodes: widget.episodes,
                        currentEpisodeIndex: widget.currentEpisodeIndex,
                        sourceType: widget.sourceType,
                        strings: widget.strings,
                        onBack: widget.onExitFullscreen,
                        onPanelRequested: _showSidePanel,
                        onMore: _showLandscapeMorePanel,
                        onInteraction: _showControls,
                      )
                    : PortraitPlayerControls(
                        controller: widget.controller,
                        value: widget.value,
                        strings: widget.strings,
                        onBack: widget.onBack,
                        onMore: _showPortraitMoreSheet,
                        onEnterFullscreen: widget.onEnterFullscreen,
                        onInteraction: _showControls,
                      ),
              ),
          if (widget.value.hasError)
            ErrorOverlay(
              error: widget.value.error!,
              onRetry: () => widget.controller.retry(autoPlay: true),
              strings: widget.strings,
            ),
        ],
      ),
    );

    if (widget.isFullscreen) {
      return ColoredBox(color: Colors.black, child: content);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: content);
  }

  void _toggleControls() {
    if (widget.value.hasError) {
      return;
    }
    if (_sidePanel != null) {
      setState(() {
        _sidePanel = null;
      });
      return;
    }
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    _scheduleAutoHide();
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _scheduleAutoHide();
  }

  Future<void> _showPortraitMoreSheet() async {
    await _handleOptionSheetOpened(
      PortraitMoreSheet.show(
        context: context,
        value: widget.value,
        isPrecacheRunning: widget.isPrecacheRunning,
        precacheSupported: widget.precacheSupported,
        autoPlayNext: widget.autoPlayNext,
        loopMode: widget.loopMode,
        onPrecache: widget.onPrecache,
        onSpeedSelected: widget.onSpeedSelected,
        onAutoPlayNextChanged: widget.onAutoPlayNextChanged,
        onLoopModeChanged: widget.onLoopModeChanged,
        strings: widget.strings,
      ),
    );
  }

  Future<T?> _handleOptionSheetOpened<T>(Future<T?> sheet) async {
    setState(() {
      _optionSheetOpen = true;
      _controlsVisible = true;
    });
    _overlayTimer?.cancel();
    try {
      return await sheet;
    } finally {
      if (mounted) {
        setState(() {
          _optionSheetOpen = false;
        });
        _scheduleAutoHide();
      }
    }
  }

  void _showSidePanel(LandscapeSidePanelType panel) {
    setState(() {
      _sidePanel = panel;
      _controlsVisible = true;
      _optionSheetOpen = true;
    });
    _overlayTimer?.cancel();
  }

  void _showLandscapeMorePanel() {
    setState(() {
      _sidePanel = LandscapeSidePanelType.more;
      _controlsVisible = true;
      _optionSheetOpen = true;
    });
    _overlayTimer?.cancel();
  }

  void _closeSidePanel() {
    setState(() {
      _sidePanel = null;
      _optionSheetOpen = false;
    });
    _scheduleAutoHide();
  }

  Widget _buildLandscapeSidePanel() {
    final panel = _sidePanel!;
    return switch (panel) {
      LandscapeSidePanelType.subtitles => _SubtitleSidePanel(
        strings: widget.strings,
        value: widget.value,
        onSelected: (subtitleId) {
          widget.controller.setSubtitle(subtitleId);
          _closeSidePanel();
        },
      ),
      LandscapeSidePanelType.speed => _SpeedSidePanel(
        value: widget.value,
        onSelected: (speed) {
          widget.controller.setPlaybackSpeed(speed);
          _closeSidePanel();
        },
      ),
      LandscapeSidePanelType.quality => _QualitySidePanel(
        strings: widget.strings,
        value: widget.value,
        onSelected: (quality) {
          widget.controller.setQuality(quality);
          _closeSidePanel();
        },
      ),
      LandscapeSidePanelType.episodes => EpisodeSidePanel(
        title: widget.strings.episodesLabel,
        strings: widget.strings,
        videos: widget.episodes,
        currentIndex: widget.currentEpisodeIndex,
        onSelected: (index) {
          if (index != widget.currentEpisodeIndex) {
            widget.onEpisodeSelected(index);
          }
          _closeSidePanel();
        },
      ),
      LandscapeSidePanelType.more => LandscapeMorePanel(
        value: widget.value,
        isPrecacheRunning: widget.isPrecacheRunning,
        precacheSupported: widget.precacheSupported,
        autoPlayNext: widget.autoPlayNext,
        loopMode: widget.loopMode,
        onPrecache: () {
          widget.onPrecache();
          _closeSidePanel();
        },
        onSpeedSelected: widget.onSpeedSelected,
        onAutoPlayNextChanged: widget.onAutoPlayNextChanged,
        onLoopModeChanged: widget.onLoopModeChanged,
        strings: widget.strings,
      ),
    };
  }

  void _scheduleAutoHide() {
    _overlayTimer?.cancel();
    final keepVisible =
        _optionSheetOpen ||
        !widget.value.isPlaying ||
        widget.value.isBuffering ||
        widget.value.hasError ||
        widget.isBusy;
    if (keepVisible || !_controlsVisible) {
      return;
    }
    _overlayTimer = Timer(_overlayTimeout, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }
}

class PlayerOverlayChrome extends StatelessWidget {
  const PlayerOverlayChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x26000000), Color(0xCC000000)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class PortraitPlayerControls extends StatelessWidget {
  const PortraitPlayerControls({
    super.key,
    required this.controller,
    required this.value,
    required this.strings,
    required this.onBack,
    required this.onMore,
    required this.onEnterFullscreen,
    required this.onInteraction,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;
  final VoidCallback? onBack;
  final VoidCallback onMore;
  final VoidCallback onEnterFullscreen;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _OverlayIconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icons.arrow_back,
                onPressed: onBack ?? () => Navigator.maybePop(context),
              ),
              const Spacer(),
              _OverlayIconButton(
                tooltip: strings.moreTooltip,
                icon: Icons.more_vert,
                onPressed: onMore,
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              PlaybackToggleButton(
                controller: controller,
                value: value,
                strings: strings,
                onInteraction: onInteraction,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _OverlaySeekBar(
                  controller: controller,
                  value: value,
                  strings: strings,
                ),
              ),
              const SizedBox(width: 8),
              PlaybackTimeLabel(value: value),
              const SizedBox(width: 4),
              _OverlayIconButton(
                tooltip: strings.fullscreenTooltip,
                icon: Icons.fullscreen,
                onPressed: onEnterFullscreen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LandscapePlayerControls extends StatelessWidget {
  const LandscapePlayerControls({
    super.key,
    required this.controller,
    required this.value,
    required this.title,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.sourceType,
    required this.strings,
    required this.onBack,
    required this.onPanelRequested,
    required this.onMore,
    required this.onInteraction,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final String title;
  final List<String> episodes;
  final int currentEpisodeIndex;
  final M3u8SourceType sourceType;
  final ExampleStrings strings;
  final VoidCallback onBack;
  final ValueChanged<LandscapeSidePanelType> onPanelRequested;
  final VoidCallback onMore;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              _OverlayIconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icons.arrow_back_ios_new,
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(child: MarqueeTitle(title: title)),
              const SizedBox(width: 8),
              _OverlayIconButton(
                tooltip: strings.moreTooltip,
                icon: Icons.more_vert,
                onPressed: onMore,
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlaybackTimeLabel(value: value, alignment: Alignment.centerLeft),
              const SizedBox(height: 4),
              _OverlaySeekBar(
                controller: controller,
                value: value,
                strings: strings,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  PlaybackToggleButton(
                    controller: controller,
                    value: value,
                    strings: strings,
                    onInteraction: onInteraction,
                    size: 54,
                  ),
                  const SizedBox(width: 28),
                  _TextControlButton(
                    label: strings.subtitlesLabel,
                    onPressed: value.isInitialized
                        ? () =>
                              onPanelRequested(LandscapeSidePanelType.subtitles)
                        : null,
                  ),
                  const SizedBox(width: 24),
                  _TextControlButton(
                    label: speedLabel(value.playbackSpeed),
                    onPressed: value.isInitialized
                        ? () => onPanelRequested(LandscapeSidePanelType.speed)
                        : null,
                  ),
                  const Spacer(),
                  _TextControlButton(
                    label: qualityLabel(value.selectedQuality, strings),
                    onPressed:
                        value.isInitialized &&
                            sourceType != M3u8SourceType.progressive
                        ? () => onPanelRequested(LandscapeSidePanelType.quality)
                        : null,
                  ),
                  const SizedBox(width: 24),
                  _TextControlButton(
                    label: strings.episodesLabel,
                    onPressed: episodes.isEmpty
                        ? null
                        : () =>
                              onPanelRequested(LandscapeSidePanelType.episodes),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum LandscapeSidePanelType { subtitles, speed, quality, episodes, more }

class PlaybackToggleButton extends StatelessWidget {
  const PlaybackToggleButton({
    super.key,
    required this.controller,
    required this.value,
    required this.strings,
    required this.onInteraction,
    this.size = 42,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;
  final VoidCallback onInteraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: value.isPlaying ? strings.pauseTooltip : strings.playTooltip,
      onPressed: value.isInitialized
          ? () {
              onInteraction();
              if (value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            }
          : null,
      icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
      color: Colors.white,
      iconSize: size,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(size, size),
      ),
    );
  }
}

class PlaybackTimeLabel extends StatelessWidget {
  const PlaybackTimeLabel({
    super.key,
    required this.value,
    this.alignment = Alignment.center,
  });

  final M3u8PlayerValue value;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Text(
        '${formatDuration(value.position)}/${formatDuration(value.duration)}',
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OverlaySeekBar extends StatelessWidget {
  const _OverlaySeekBar({
    required this.controller,
    required this.value,
    required this.strings,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: BufferedSeekBar(
        controller: controller,
        value: value,
        strings: strings,
        isOverlay: true,
      ),
    );
  }
}

class MarqueeTitle extends StatefulWidget {
  const MarqueeTitle({super.key, required this.title});

  final String title;

  @override
  State<MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<MarqueeTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _controller.value < 0.2
              ? 0.0
              : -220.0 * ((_controller.value - 0.2) / 0.8);
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: Text(
          widget.title,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class PlayerOption<T> {
  const PlayerOption({required this.label, required this.value});

  final String label;
  final T value;
}

class PlayerOptionSheet {
  const PlayerOptionSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<PlayerOption<T>> options,
    T? selectedValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xF21A1A1A),
      barrierColor: Colors.black45,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final option in options)
                  ListTile(
                    title: Text(
                      option.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: option.value == selectedValue
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () => Navigator.pop(context, option.value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubtitleSidePanel extends StatelessWidget {
  const _SubtitleSidePanel({
    required this.strings,
    required this.value,
    required this.onSelected,
  });

  final ExampleStrings strings;
  final M3u8PlayerValue value;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    const offValue = '__off__';
    return PlayerSidePanel<String>(
      widthFactor: 0.32,
      selectedValue: value.selectedSubtitle?.id ?? offValue,
      options: [
        PlayerOption<String>(label: strings.subtitlesOffLabel, value: offValue),
        for (final subtitle in value.availableSubtitles)
          PlayerOption<String>(label: subtitle.label, value: subtitle.id),
      ],
      onSelected: (subtitleId) {
        onSelected(subtitleId == offValue ? null : subtitleId);
      },
    );
  }
}

class _SpeedSidePanel extends StatelessWidget {
  const _SpeedSidePanel({required this.value, required this.onSelected});

  final M3u8PlayerValue value;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    const speeds = <double>[2.0, 1.5, 1.25, 1.0, 0.75, 0.5];
    return PlayerSidePanel<double>(
      widthFactor: 0.32,
      selectedValue: nearestSpeed(value.playbackSpeed, speeds),
      options: [
        for (final speed in speeds)
          PlayerOption<double>(label: speedLabel(speed), value: speed),
      ],
      onSelected: onSelected,
    );
  }
}

class _QualitySidePanel extends StatelessWidget {
  const _QualitySidePanel({
    required this.strings,
    required this.value,
    required this.onSelected,
  });

  final ExampleStrings strings;
  final M3u8PlayerValue value;
  final ValueChanged<M3u8Quality> onSelected;

  @override
  Widget build(BuildContext context) {
    final qualities = <M3u8Quality>[
      M3u8Quality.auto,
      ...value.availableQualities,
    ];
    return PlayerSidePanel<String>(
      widthFactor: 0.34,
      selectedValue: value.selectedQuality.id,
      options: [
        for (final quality in qualities)
          PlayerOption<String>(
            label: qualityLabel(quality, strings),
            value: quality.id,
          ),
      ],
      onSelected: (qualityId) {
        final quality = qualities.firstWhere(
          (item) => item.id == qualityId,
          orElse: () => M3u8Quality.auto,
        );
        onSelected(quality);
      },
    );
  }
}

class PlayerSidePanel<T> extends StatelessWidget {
  const PlayerSidePanel({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.widthFactor = 0.34,
  });

  final List<PlayerOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: 1,
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final option = options[index];
                return _SidePanelOptionTile(
                  label: option.label,
                  selected: option.value == selectedValue,
                  onTap: () => onSelected(option.value),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class EpisodeSidePanel extends StatelessWidget {
  const EpisodeSidePanel({
    super.key,
    required this.title,
    required this.strings,
    required this.videos,
    required this.currentIndex,
    required this.onSelected,
  });

  final String title;
  final ExampleStrings strings;
  final List<String> videos;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.42,
        heightFactor: 1,
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      TextSpan(
                        text: strings.episodeCount(videos.length),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: videos.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 24, color: Color(0x26FFFFFF)),
                    itemBuilder: (context, index) {
                      return _EpisodeTile(
                        index: index,
                        title: videos[index],
                        strings: strings,
                        selected: index == currentIndex,
                        onTap: () => onSelected(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanelOptionTile extends StatelessWidget {
  const _SidePanelOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 74,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 34),
        decoration: BoxDecoration(
          color: const Color(0xE62A2B31),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFFFF6FA8) : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.index,
    required this.title,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String title;
  final ExampleStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFF6FA8) : Colors.white;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            Container(
              width: 138,
              height: 78,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? const [Color(0xFF3D2430), Color(0xFF111111)]
                      : const [Color(0xFF3B3E45), Color(0xFF17191D)],
                ),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      height: 1.18,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    selected
                        ? strings.nowPlayingLabel
                        : strings.episodeNumber(index + 1),
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? color : Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      iconSize: 28,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _TextControlButton extends StatelessWidget {
  const _TextControlButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(44, 40),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ErrorOverlay extends StatelessWidget {
  const ErrorOverlay({
    super.key,
    required this.error,
    required this.onRetry,
    required this.strings,
  });

  final M3u8PlayerError error;
  final VoidCallback onRetry;
  final ExampleStrings strings;

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
                label: Text(strings.retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortraitMoreSheet {
  const PortraitMoreSheet._();

  static Future<void> show({
    required BuildContext context,
    required M3u8PlayerValue value,
    required bool isPrecacheRunning,
    required bool precacheSupported,
    required bool autoPlayNext,
    required ExampleLoopMode loopMode,
    required VoidCallback onPrecache,
    required ValueChanged<double> onSpeedSelected,
    required ValueChanged<bool> onAutoPlayNextChanged,
    required ValueChanged<ExampleLoopMode> onLoopModeChanged,
    required ExampleStrings strings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _PortraitMoreSheetBody(
          value: value,
          isPrecacheRunning: isPrecacheRunning,
          precacheSupported: precacheSupported,
          autoPlayNext: autoPlayNext,
          loopMode: loopMode,
          onPrecache: onPrecache,
          onSpeedSelected: onSpeedSelected,
          onAutoPlayNextChanged: onAutoPlayNextChanged,
          onLoopModeChanged: onLoopModeChanged,
          strings: strings,
        );
      },
    );
  }
}

class LandscapeMorePanel extends StatelessWidget {
  LandscapeMorePanel({
    super.key,
    required M3u8PlayerValue value,
    required bool isPrecacheRunning,
    required bool precacheSupported,
    required bool autoPlayNext,
    required ExampleLoopMode loopMode,
    required VoidCallback onPrecache,
    required ValueChanged<double> onSpeedSelected,
    required ValueChanged<bool> onAutoPlayNextChanged,
    required ValueChanged<ExampleLoopMode> onLoopModeChanged,
    required ExampleStrings strings,
  }) : _body = _LandscapeMorePanelBody(
         value: value,
         isPrecacheRunning: isPrecacheRunning,
         precacheSupported: precacheSupported,
         autoPlayNext: autoPlayNext,
         loopMode: loopMode,
         onPrecache: onPrecache,
         onSpeedSelected: onSpeedSelected,
         onAutoPlayNextChanged: onAutoPlayNextChanged,
         onLoopModeChanged: onLoopModeChanged,
         strings: strings,
       );

  final _LandscapeMorePanelBody _body;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.42,
        heightFactor: 1,
        child: Material(color: Colors.black, child: _body),
      ),
    );
  }
}

class _PortraitMoreSheetBody extends StatefulWidget {
  const _PortraitMoreSheetBody({
    required this.value,
    required this.isPrecacheRunning,
    required this.precacheSupported,
    required this.autoPlayNext,
    required this.loopMode,
    required this.onPrecache,
    required this.onSpeedSelected,
    required this.onAutoPlayNextChanged,
    required this.onLoopModeChanged,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final bool isPrecacheRunning;
  final bool precacheSupported;
  final bool autoPlayNext;
  final ExampleLoopMode loopMode;
  final VoidCallback onPrecache;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onAutoPlayNextChanged;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  final ExampleStrings strings;

  @override
  State<_PortraitMoreSheetBody> createState() => _PortraitMoreSheetBodyState();
}

class _PortraitMoreSheetBodyState extends State<_PortraitMoreSheetBody> {
  late bool _autoPlayNext = widget.autoPlayNext;
  late ExampleLoopMode _loopMode = widget.loopMode;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6F7F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D2D6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MoreActionButton(
                    icon: Icons.sentiment_dissatisfied_outlined,
                    label: widget.strings.notInterestedLabel,
                    onPressed: () {},
                  ),
                  _MoreActionButton(
                    icon: Icons.replay_circle_filled_outlined,
                    label: widget.strings.watchLaterLabel,
                    onPressed: () {},
                  ),
                  _MoreActionButton(
                    icon: Icons.download_for_offline_outlined,
                    label: widget.isPrecacheRunning
                        ? widget.strings.cachingLabel
                        : widget.strings.cacheLabel,
                    onPressed:
                        widget.precacheSupported && !widget.isPrecacheRunning
                        ? widget.onPrecache
                        : null,
                  ),
                  _MoreActionButton(
                    icon: Icons.picture_in_picture_alt_outlined,
                    label: widget.strings.pipLabel,
                    onPressed: () {},
                  ),
                  _MoreActionButton(
                    icon: Icons.connected_tv_outlined,
                    label: widget.strings.castLabel,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MoreSettingsCard(
                foregroundColor: Colors.black87,
                dividerColor: const Color(0xFFE7E8EC),
                children: [
                  _SpeedSettingRow(
                    value: widget.value,
                    onSpeedSelected: widget.onSpeedSelected,
                    isDark: false,
                    strings: widget.strings,
                  ),
                  _SwitchSettingRow(
                    icon: Icons.skip_next,
                    label: widget.strings.autoPlayNextLabel,
                    value: _autoPlayNext,
                    onChanged: _setAutoPlayNext,
                    isDark: false,
                  ),
                  _LoopSettingRow(
                    loopMode: _loopMode,
                    onLoopModeChanged: _setLoopMode,
                    isDark: false,
                    strings: widget.strings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setAutoPlayNext(bool value) {
    setState(() {
      _autoPlayNext = value;
    });
    widget.onAutoPlayNextChanged(value);
  }

  void _setLoopMode(ExampleLoopMode mode) {
    setState(() {
      _loopMode = mode;
    });
    widget.onLoopModeChanged(mode);
  }
}

class _LandscapeMorePanelBody extends StatefulWidget {
  const _LandscapeMorePanelBody({
    required this.value,
    required this.isPrecacheRunning,
    required this.precacheSupported,
    required this.autoPlayNext,
    required this.loopMode,
    required this.onPrecache,
    required this.onSpeedSelected,
    required this.onAutoPlayNextChanged,
    required this.onLoopModeChanged,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final bool isPrecacheRunning;
  final bool precacheSupported;
  final bool autoPlayNext;
  final ExampleLoopMode loopMode;
  final VoidCallback onPrecache;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onAutoPlayNextChanged;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  final ExampleStrings strings;

  @override
  State<_LandscapeMorePanelBody> createState() =>
      _LandscapeMorePanelBodyState();
}

class _LandscapeMorePanelBodyState extends State<_LandscapeMorePanelBody> {
  late bool _autoPlayNext = widget.autoPlayNext;
  late ExampleLoopMode _loopMode = widget.loopMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MoreActionButton(
                icon: Icons.replay_circle_filled_outlined,
                label: widget.strings.watchLaterLabel,
                isDark: true,
                onPressed: () {},
              ),
              _MoreActionButton(
                icon: Icons.download_for_offline_outlined,
                label: widget.isPrecacheRunning
                    ? widget.strings.cachingLabel
                    : widget.strings.cacheLabel,
                isDark: true,
                onPressed: widget.precacheSupported && !widget.isPrecacheRunning
                    ? widget.onPrecache
                    : null,
              ),
              _MoreActionButton(
                icon: Icons.connected_tv_outlined,
                label: widget.strings.castLabel,
                isDark: true,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SpeedSettingRow(
            value: widget.value,
            onSpeedSelected: widget.onSpeedSelected,
            isDark: true,
            strings: widget.strings,
          ),
          const SizedBox(height: 14),
          _MoreSettingsCard(
            foregroundColor: Colors.white,
            dividerColor: const Color(0x22FFFFFF),
            backgroundColor: const Color(0xD9222328),
            children: [
              _SwitchSettingRow(
                icon: Icons.skip_next,
                label: widget.strings.autoPlayNextLabel,
                value: _autoPlayNext,
                onChanged: _setAutoPlayNext,
                isDark: true,
              ),
              _LoopSettingRow(
                loopMode: _loopMode,
                onLoopModeChanged: _setLoopMode,
                isDark: true,
                strings: widget.strings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setAutoPlayNext(bool value) {
    setState(() {
      _autoPlayNext = value;
    });
    widget.onAutoPlayNextChanged(value);
  }

  void _setLoopMode(ExampleLoopMode mode) {
    setState(() {
      _loopMode = mode;
    });
    widget.onLoopModeChanged(mode);
  }
}

class _MoreActionButton extends StatelessWidget {
  const _MoreActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDark = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = isDark ? Colors.white : Colors.black;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: enabled ? color : color.withValues(alpha: 0.32),
          iconSize: isDark ? 25 : 27,
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xCC24262C)
                : const Color(0xFFFFFFFF),
            fixedSize: isDark ? const Size(52, 48) : const Size(56, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: enabled ? 0.68 : 0.32),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MoreSettingsCard extends StatelessWidget {
  const _MoreSettingsCard({
    required this.children,
    required this.foregroundColor,
    required this.dividerColor,
    this.backgroundColor = Colors.white,
  });

  final List<Widget> children;
  final Color foregroundColor;
  final Color dividerColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: foregroundColor, size: 25),
      child: DefaultTextStyle(
        style: TextStyle(color: foregroundColor, fontSize: 18),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, indent: 54, color: dividerColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedSettingRow extends StatelessWidget {
  const _SpeedSettingRow({
    required this.value,
    required this.onSpeedSelected,
    required this.isDark,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final ValueChanged<double> onSpeedSelected;
  final bool isDark;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    const speeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];
    final selected = nearestSpeed(value.playbackSpeed, speeds);
    final color = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Icon(Icons.fast_forward, color: color),
          const SizedBox(width: 10),
          Text(
            strings.playbackSpeedLabel,
            style: TextStyle(color: color, fontSize: 16),
          ),
          const Spacer(),
          for (final speed in speeds) ...[
            TextButton(
              onPressed: () => onSpeedSelected(speed),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                speedLabel(speed),
                style: TextStyle(
                  color: speed == selected
                      ? const Color(0xFFFF5C93)
                      : color.withValues(alpha: 0.58),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 16)),
          const Spacer(),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFF5C93),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LoopSettingRow extends StatelessWidget {
  const _LoopSettingRow({
    required this.loopMode,
    required this.onLoopModeChanged,
    required this.isDark,
    required this.strings,
  });

  final ExampleLoopMode loopMode;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  final bool isDark;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.loop, color: color),
          const SizedBox(width: 10),
          Text(
            strings.loopPlaybackLabel,
            style: TextStyle(color: color, fontSize: 16),
          ),
          const Spacer(),
          _LoopModeButton(
            label: strings.singleLoopLabel,
            selected: loopMode == ExampleLoopMode.single,
            onPressed: () => onLoopModeChanged(ExampleLoopMode.single),
            isDark: isDark,
          ),
          _LoopModeButton(
            label: strings.playlistLoopLabel,
            selected: loopMode == ExampleLoopMode.playlist,
            onPressed: () => onLoopModeChanged(ExampleLoopMode.playlist),
            isDark: isDark,
          ),
          _LoopModeButton(
            label: strings.noLoopLabel,
            selected: loopMode == ExampleLoopMode.none,
            onPressed: () => onLoopModeChanged(ExampleLoopMode.none),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _LoopModeButton extends StatelessWidget {
  const _LoopModeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        minimumSize: const Size(36, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: selected
              ? const Color(0xFFFF5C93)
              : (isDark ? Colors.white60 : Colors.black45),
          fontSize: 13,
        ),
      ),
    );
  }
}
