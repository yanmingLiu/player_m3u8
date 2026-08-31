import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import '../localization/example_strings.dart';

class BufferedSeekBar extends StatefulWidget {
  const BufferedSeekBar({
    super.key,
    required this.controller,
    required this.value,
    required this.strings,
    this.isOverlay = false,
    this.onScrubbingChanged,
    this.onScrubPositionChanged,
    this.baseColor,
    this.bufferedColor,
    this.playedColor,
    this.thumbColor = const Color(0xFFFFFFFF),
    this.thumbBorderColor,
    this.thumbRadius = 6,
    this.progressHeight = 4,
    this.verticalPadding = 15,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;
  final bool isOverlay;

  /// Called with `true` while the user is dragging and `false` afterwards.
  final ValueChanged<bool>? onScrubbingChanged;

  /// Reports the current drag target, or `null` when dragging ends/cancels.
  final ValueChanged<Duration?>? onScrubPositionChanged;
  final Color? baseColor;
  final Color? bufferedColor;
  final Color? playedColor;
  final Color thumbColor;
  final Color? thumbBorderColor;
  final double thumbRadius;

  /// Visual track height. The vertical padding supplies the touch area.
  final double progressHeight;
  final double verticalPadding;

  @override
  State<BufferedSeekBar> createState() => BufferedSeekBarState();
}

class BufferedSeekBarState extends State<BufferedSeekBar> {
  bool _isScrubbing = false;
  double? _scrubFraction;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final durationMs = value.duration.inMilliseconds;
    final positionMs = durationMs == 0
        ? 0
        : value.position.inMilliseconds.clamp(0, durationMs);
    final bufferedMs = durationMs == 0
        ? 0
        : value.visibleBufferedPosition.inMilliseconds.clamp(0, durationMs);
    final bufferedStartMs = durationMs == 0
        ? 0
        : value.visibleBufferedStartPosition.inMilliseconds.clamp(
            0,
            bufferedMs,
          );
    final enabled = value.isInitialized && durationMs > 0;
    final playedFraction = durationMs == 0
        ? 0.0
        : (_scrubFraction ?? positionMs / durationMs);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      height: widget.progressHeight + widget.verticalPadding * 2,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled
                ? (TapDownDetails details) {
                    _seekFromDx(details.localPosition.dx, constraints.maxWidth);
                  }
                : null,
            onHorizontalDragStart: enabled
                ? (DragStartDetails details) {
                    _beginScrub(details.localPosition.dx, constraints.maxWidth);
                  }
                : null,
            onHorizontalDragUpdate: enabled
                ? (DragUpdateDetails details) {
                    _updateScrub(
                      details.localPosition.dx,
                      constraints.maxWidth,
                    );
                  }
                : null,
            onHorizontalDragEnd: enabled ? (_) => _endScrub() : null,
            onHorizontalDragCancel: enabled ? _cancelScrub : null,
            child: Semantics(
              label: widget.strings.playbackProgressSemantics,
              value: widget.strings.playbackProgressValue(
                value.position,
                value.duration,
              ),
              child: CustomPaint(
                painter: _BufferedTrackPainter(
                  playedFraction: playedFraction,
                  bufferedStartFraction: durationMs == 0
                      ? 0
                      : bufferedStartMs / durationMs,
                  bufferedFraction: durationMs == 0
                      ? 0
                      : bufferedMs / durationMs,
                  isScrubbing: _isScrubbing,
                  isOverlay: widget.isOverlay,
                  baseColor: widget.baseColor,
                  bufferedColor: widget.bufferedColor,
                  playedColor: widget.playedColor,
                  thumbColor: widget.thumbColor,
                  thumbBorderColor: widget.thumbBorderColor,
                  thumbRadius: widget.thumbRadius,
                  progressHeight: widget.progressHeight,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _beginScrub(double dx, double width) {
    final fraction = _fractionForDx(dx, width);
    setState(() {
      _isScrubbing = true;
      _scrubFraction = fraction;
    });
    widget.onScrubPositionChanged?.call(_positionForFraction(fraction));
    widget.onScrubbingChanged?.call(true);
  }

  void _updateScrub(double dx, double width) {
    final fraction = _fractionForDx(dx, width);
    setState(() {
      _scrubFraction = fraction;
    });
    widget.onScrubPositionChanged?.call(_positionForFraction(fraction));
  }

  void _endScrub() {
    if (!_isScrubbing) {
      return;
    }
    final fraction = _scrubFraction;
    setState(() {
      _isScrubbing = false;
      _scrubFraction = null;
    });
    widget.onScrubbingChanged?.call(false);
    widget.onScrubPositionChanged?.call(null);
    _seekToFraction(fraction);
  }

  void _cancelScrub() {
    if (!_isScrubbing) {
      return;
    }
    setState(() {
      _isScrubbing = false;
      _scrubFraction = null;
    });
    widget.onScrubbingChanged?.call(false);
    widget.onScrubPositionChanged?.call(null);
  }

  void _seekFromDx(double dx, double width) {
    final fraction = _fractionForDx(dx, width);
    _seekToFraction(fraction);
  }

  double _fractionForDx(double dx, double width) {
    if (width <= 0) {
      return 0;
    }
    return (dx / width).clamp(0.0, 1.0);
  }

  void _seekToFraction(double? fraction) {
    final position = fraction == null ? null : _positionForFraction(fraction);
    if (position == null) {
      return;
    }
    widget.controller.seekTo(position);
  }

  Duration? _positionForFraction(double fraction) {
    final durationMs = widget.value.duration.inMilliseconds;
    if (durationMs <= 0) {
      return null;
    }
    return Duration(milliseconds: (durationMs * fraction).round());
  }
}

class _BufferedTrackPainter extends CustomPainter {
  const _BufferedTrackPainter({
    required this.playedFraction,
    required this.bufferedStartFraction,
    required this.bufferedFraction,
    required this.isScrubbing,
    required this.isOverlay,
    required this.baseColor,
    required this.bufferedColor,
    required this.playedColor,
    required this.thumbColor,
    required this.thumbBorderColor,
    required this.thumbRadius,
    required this.progressHeight,
  });

  final double playedFraction;
  final double bufferedStartFraction;
  final double bufferedFraction;
  final bool isScrubbing;
  final bool isOverlay;
  final Color? baseColor;
  final Color? bufferedColor;
  final Color? playedColor;
  final Color thumbColor;
  final Color? thumbBorderColor;
  final double thumbRadius;
  final double progressHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final baseHeight = progressHeight;
    final bufferedHeight = progressHeight;
    final playedHeight = progressHeight;
    final centerY = size.height / 2;
    final baseRect = Rect.fromLTWH(
      0,
      centerY - baseHeight / 2,
      size.width,
      baseHeight,
    );
    final bufferedRect = Rect.fromLTWH(
      0,
      centerY - bufferedHeight / 2,
      size.width,
      bufferedHeight,
    );
    final playedRect = Rect.fromLTWH(
      0,
      centerY - playedHeight / 2,
      size.width,
      playedHeight,
    );

    void drawSegment({
      required Rect rect,
      double startFraction = 0,
      required double fraction,
      required Color color,
    }) {
      final start = startFraction.clamp(0.0, 1.0).toDouble();
      final end = fraction.clamp(start, 1.0).toDouble();
      final left = rect.left + rect.width * start;
      final width = rect.width * (end - start);
      if (width <= 0) {
        return;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, rect.top, width, rect.height),
          Radius.circular(rect.height / 2),
        ),
        Paint()..color = color,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, Radius.circular(baseRect.height / 2)),
      Paint()
        ..color =
            baseColor ??
            (isOverlay ? const Color(0x66FFFFFF) : const Color(0xFFD6DDD9)),
    );
    drawSegment(
      rect: bufferedRect,
      startFraction: bufferedStartFraction,
      fraction: bufferedFraction,
      color:
          bufferedColor ??
          (isOverlay ? const Color(0x80FFFFFF) : const Color(0xFFFFB74D)),
    );
    drawSegment(
      rect: playedRect,
      fraction: playedFraction,
      color:
          playedColor ??
          (isOverlay ? const Color(0xFFFF5C93) : const Color(0xFF006B5F)),
    );

    final markerX = size.width * playedFraction.clamp(0.0, 1.0);
    if (!isScrubbing) {
      return;
    }
    canvas.drawCircle(
      Offset(markerX, centerY),
      thumbRadius,
      Paint()..color = thumbColor,
    );
    canvas.drawCircle(
      Offset(markerX, centerY),
      thumbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color =
            thumbBorderColor ??
            (playedColor ??
                (isOverlay
                    ? const Color(0xFFFF5C93)
                    : const Color(0xFF006B5F))),
    );
  }

  @override
  bool shouldRepaint(covariant _BufferedTrackPainter oldDelegate) {
    return oldDelegate.playedFraction != playedFraction ||
        oldDelegate.bufferedStartFraction != bufferedStartFraction ||
        oldDelegate.bufferedFraction != bufferedFraction ||
        oldDelegate.isScrubbing != isScrubbing ||
        oldDelegate.isOverlay != isOverlay ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.bufferedColor != bufferedColor ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.thumbColor != thumbColor ||
        oldDelegate.thumbBorderColor != thumbBorderColor ||
        oldDelegate.thumbRadius != thumbRadius ||
        oldDelegate.progressHeight != progressHeight;
  }
}
