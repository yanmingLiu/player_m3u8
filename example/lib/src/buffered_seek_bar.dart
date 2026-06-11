import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

import 'example_strings.dart';

class BufferedSeekBar extends StatefulWidget {
  const BufferedSeekBar({
    super.key,
    required this.controller,
    required this.value,
    required this.strings,
    this.isOverlay = false,
  });

  final M3u8PlayerController controller;
  final M3u8PlayerValue value;
  final ExampleStrings strings;
  final bool isOverlay;

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
      height: _isScrubbing ? 48 : 36,
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
    setState(() {
      _isScrubbing = true;
      _scrubFraction = _fractionForDx(dx, width);
    });
  }

  void _updateScrub(double dx, double width) {
    final fraction = _fractionForDx(dx, width);
    setState(() {
      _scrubFraction = fraction;
    });
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
    final durationMs = widget.value.duration.inMilliseconds;
    if (fraction == null || durationMs <= 0) {
      return;
    }
    widget.controller.seekTo(
      Duration(milliseconds: (durationMs * fraction).round()),
    );
  }
}

class _BufferedTrackPainter extends CustomPainter {
  const _BufferedTrackPainter({
    required this.playedFraction,
    required this.bufferedStartFraction,
    required this.bufferedFraction,
    required this.isScrubbing,
    required this.isOverlay,
  });

  final double playedFraction;
  final double bufferedStartFraction;
  final double bufferedFraction;
  final bool isScrubbing;
  final bool isOverlay;

  @override
  void paint(Canvas canvas, Size size) {
    final baseHeight = isScrubbing ? 7.0 : 4.0;
    final bufferedHeight = isScrubbing ? 9.0 : 6.0;
    final playedHeight = isScrubbing ? 12.0 : 7.0;
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
        ..color = isOverlay ? const Color(0x66FFFFFF) : const Color(0xFFD6DDD9),
    );
    drawSegment(
      rect: bufferedRect,
      startFraction: bufferedStartFraction,
      fraction: bufferedFraction,
      color: isOverlay ? const Color(0x80FFFFFF) : const Color(0xFFFFB74D),
    );
    drawSegment(
      rect: playedRect,
      fraction: playedFraction,
      color: isOverlay ? const Color(0xFFFF5C93) : const Color(0xFF006B5F),
    );

    final markerX = size.width * playedFraction.clamp(0.0, 1.0);
    if (!isScrubbing) {
      return;
    }
    canvas.drawCircle(
      Offset(markerX, centerY),
      10,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      Offset(markerX, centerY),
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = isOverlay ? const Color(0xFFFF5C93) : const Color(0xFF006B5F),
    );
  }

  @override
  bool shouldRepaint(covariant _BufferedTrackPainter oldDelegate) {
    return oldDelegate.playedFraction != playedFraction ||
        oldDelegate.bufferedStartFraction != bufferedStartFraction ||
        oldDelegate.bufferedFraction != bufferedFraction ||
        oldDelegate.isScrubbing != isScrubbing ||
        oldDelegate.isOverlay != isOverlay;
  }
}
