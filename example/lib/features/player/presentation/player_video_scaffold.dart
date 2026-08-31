import 'dart:async';

import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import '../../../shared/formatters.dart';
import '../../../shared/localization/example_strings.dart';
import '../../../shared/widgets/buffered_seek_bar.dart';

part 'player_video_option_panels.dart';
// These parts keep private controls private while keeping each UI concern in
// a focused file. They intentionally share this library's imports and types.
part 'player_video_scaffold_sheets.dart';

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
    required this.controlsLocked,
    required this.isBusy,
    required this.isPrecacheRunning,
    required this.precacheSupported,
    required this.autoPlayNext,
    required this.loopMode,
    required this.onBack,
    required this.onEnterFullscreen,
    required this.onExitFullscreen,
    required this.onControlsLockedChanged,
    required this.onEpisodeSelected,
    required this.onPrecache,
    required this.onShowDownloads,
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
  final bool controlsLocked;
  final bool isBusy;
  final bool isPrecacheRunning;
  final bool precacheSupported;
  final bool autoPlayNext;
  final ExampleLoopMode loopMode;
  final VoidCallback? onBack;
  final VoidCallback onEnterFullscreen;
  final VoidCallback onExitFullscreen;
  final ValueChanged<bool> onControlsLockedChanged;
  final ValueChanged<int> onEpisodeSelected;
  final VoidCallback onPrecache;
  final VoidCallback onShowDownloads;
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
        widget.controlsLocked != oldWidget.controlsLocked ||
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
    // Side panels own vertical scrolling. Disable the full-screen gesture
    // listener while one is open so panel drags cannot change volume/brightness.
    final gestureConfig = widget.controlsLocked || _sidePanel != null
        ? const M3u8GestureControlsConfig(enabled: false)
        : const M3u8GestureControlsConfig();
    final content = M3u8PlayerGestureControls(
      controller: widget.controller,
      config: gestureConfig,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          M3u8Player(controller: widget.controller, fit: BoxFit.contain),
          if (widget.controlsLocked && !_controlsVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showControls,
              ),
            ),
          if (widget.isBusy || widget.value.isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_controlsVisible && !widget.value.hasError)
            if (widget.controlsLocked)
              LockedLandscapeControls(
                strings: widget.strings,
                onUnlock: _unlockControls,
              )
            else if (widget.isFullscreen && _sidePanel != null)
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
                        onLock: _lockControls,
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
    if (widget.controlsLocked) {
      setState(() {
        _controlsVisible = true;
      });
      _scheduleAutoHide();
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
    if (widget.controlsLocked) {
      setState(() {
        _controlsVisible = true;
      });
      _scheduleAutoHide();
      return;
    }
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
        onShowDownloads: widget.onShowDownloads,
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

  void _lockControls() {
    setState(() {
      _controlsVisible = true;
      _sidePanel = null;
      _optionSheetOpen = false;
    });
    widget.onControlsLockedChanged(true);
    _scheduleAutoHide();
  }

  void _unlockControls() {
    setState(() {
      _controlsVisible = true;
    });
    widget.onControlsLockedChanged(false);
    _scheduleAutoHide();
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
    final sidePanel = switch (panel) {
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
        onShowDownloads: () {
          _closeSidePanel();
          widget.onShowDownloads();
        },
        onSpeedSelected: widget.onSpeedSelected,
        onAutoPlayNextChanged: widget.onAutoPlayNextChanged,
        onLoopModeChanged: widget.onLoopModeChanged,
        strings: widget.strings,
      ),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeSidePanel,
            child: const SizedBox.expand(),
          ),
        ),
        sidePanel,
      ],
    );
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
    required this.onLock,
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
  final VoidCallback onLock;
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
                tooltip: strings.lockControlsTooltip,
                icon: Icons.lock_open,
                onPressed: onLock,
              ),
              const SizedBox(width: 4),
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

                  Spacer(),

                  _TextControlButton(
                    label: strings.subtitlesLabel,
                    onPressed: value.isInitialized
                        ? () =>
                              onPanelRequested(LandscapeSidePanelType.subtitles)
                        : null,
                  ),

                  _TextControlButton(
                    label: strings.episodesLabel,
                    onPressed: episodes.isEmpty
                        ? null
                        : () =>
                              onPanelRequested(LandscapeSidePanelType.episodes),
                  ),

                  _TextControlButton(
                    label: speedLabel(value.playbackSpeed),
                    onPressed: value.isInitialized
                        ? () => onPanelRequested(LandscapeSidePanelType.speed)
                        : null,
                  ),

                  _TextControlButton(
                    label: qualityLabel(value.selectedQuality, strings),
                    onPressed:
                        value.isInitialized &&
                            sourceType != M3u8SourceType.progressive
                        ? () => onPanelRequested(LandscapeSidePanelType.quality)
                        : null,
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

class LockedLandscapeControls extends StatelessWidget {
  const LockedLandscapeControls({
    super.key,
    required this.strings,
    required this.onUnlock,
  });

  final ExampleStrings strings;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: const Alignment(-0.86, 0.24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.46),
            shape: BoxShape.circle,
          ),
          child: _OverlayIconButton(
            tooltip: strings.unlockControlsTooltip,
            icon: Icons.lock,
            onPressed: onUnlock,
          ),
        ),
      ),
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
