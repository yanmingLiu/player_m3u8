import 'dart:async';

import 'package:flutter/material.dart';

import 'm3u8_player_controller.dart';
import 'm3u8_screen_brightness.dart';

enum M3u8GestureControlType { brightness, volume, seek }

enum M3u8GestureAxis { horizontal, vertical }

class M3u8GestureControlsConfig {
  const M3u8GestureControlsConfig({
    this.enabled = true,
    this.brightnessEnabled = true,
    this.volumeEnabled = true,
    this.seekEnabled = true,
    this.brightnessOverlayEnabled = true,
    this.seekSensitivity = 1.0,
    this.verticalSensitivity = 1.0,
    this.overlayBuilder,
  });

  final bool enabled;
  final bool brightnessEnabled;
  final bool volumeEnabled;
  final bool seekEnabled;
  final bool brightnessOverlayEnabled;
  final double seekSensitivity;
  final double verticalSensitivity;
  final M3u8GestureOverlayBuilder? overlayBuilder;

  void debugAssertValid() {
    if (!seekSensitivity.isFinite || seekSensitivity <= 0) {
      throw ArgumentError.value(
        seekSensitivity,
        'seekSensitivity',
        'Must be finite and greater than zero.',
      );
    }
    if (!verticalSensitivity.isFinite || verticalSensitivity <= 0) {
      throw ArgumentError.value(
        verticalSensitivity,
        'verticalSensitivity',
        'Must be finite and greater than zero.',
      );
    }
  }
}

class M3u8GestureOverlayData {
  const M3u8GestureOverlayData._({
    required this.type,
    this.value,
    this.position,
    this.duration,
  });

  const M3u8GestureOverlayData.brightness(double value)
    : this._(type: M3u8GestureControlType.brightness, value: value);

  const M3u8GestureOverlayData.volume(double value)
    : this._(type: M3u8GestureControlType.volume, value: value);

  const M3u8GestureOverlayData.seek({
    required Duration position,
    required Duration duration,
  }) : this._(
         type: M3u8GestureControlType.seek,
         position: position,
         duration: duration,
       );

  final M3u8GestureControlType type;
  final double? value;
  final Duration? position;
  final Duration? duration;
}

typedef M3u8GestureOverlayBuilder =
    Widget Function(BuildContext context, M3u8GestureOverlayData data);

@visibleForTesting
class M3u8GestureDragCalculator {
  const M3u8GestureDragCalculator({
    required this.size,
    required this.startPosition,
    required this.startPlaybackPosition,
    required this.duration,
    required this.startBrightness,
    required this.startVolume,
    required this.seekSensitivity,
    required this.verticalSensitivity,
  });

  static const double directionSlop = 8;

  final Size size;
  final Offset startPosition;
  final Duration startPlaybackPosition;
  final Duration duration;
  final double startBrightness;
  final double startVolume;
  final double seekSensitivity;
  final double verticalSensitivity;

  bool get isLeftSide => startPosition.dx < size.width / 2;

  M3u8GestureAxis? axisFor(Offset delta) {
    if (delta.distance < directionSlop) {
      return null;
    }
    return delta.dx.abs() >= delta.dy.abs()
        ? M3u8GestureAxis.horizontal
        : M3u8GestureAxis.vertical;
  }

  double brightnessFor(Offset delta) {
    return _verticalValueFor(startBrightness, delta);
  }

  double volumeFor(Offset delta) {
    return _verticalValueFor(startVolume, delta);
  }

  Duration seekPositionFor(Offset delta) {
    final durationMs = duration.inMilliseconds;
    if (size.width <= 0 || durationMs <= 0) {
      return startPlaybackPosition < Duration.zero
          ? Duration.zero
          : startPlaybackPosition;
    }
    final maxDeltaMs = durationMs < 60000 ? durationMs : 60000;
    final deltaMs = (delta.dx / size.width * maxDeltaMs * seekSensitivity)
        .round();
    final targetMs = startPlaybackPosition.inMilliseconds + deltaMs;
    return Duration(milliseconds: targetMs.clamp(0, durationMs));
  }

  double _verticalValueFor(double startValue, Offset delta) {
    if (size.height <= 0) {
      return startValue.clamp(0.0, 1.0);
    }
    final change = -delta.dy / size.height * verticalSensitivity;
    return (startValue + change).clamp(0.0, 1.0);
  }
}

class M3u8PlayerGestureControls extends StatefulWidget {
  const M3u8PlayerGestureControls({
    super.key,
    required this.controller,
    required this.child,
    this.config = const M3u8GestureControlsConfig(),
    this.onTap,
  });

  final M3u8PlayerController controller;
  final Widget child;
  final M3u8GestureControlsConfig config;
  final VoidCallback? onTap;

  @override
  State<M3u8PlayerGestureControls> createState() =>
      _M3u8PlayerGestureControlsState();
}

class _M3u8PlayerGestureControlsState extends State<M3u8PlayerGestureControls> {
  M3u8GestureDragCalculator? _calculator;
  M3u8GestureAxis? _axis;
  M3u8GestureControlType? _activeType;
  M3u8GestureOverlayData? _overlayData;
  Duration? _pendingSeekPosition;
  Timer? _overlayTimer;
  double _lastBrightness = 0.5;
  int? _activePointer;

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.config.debugAssertValid();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final content = Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.config.brightnessOverlayEnabled && _lastBrightness < 1)
              IgnorePointer(
                child: ColoredBox(
                  color: Color.fromRGBO(0, 0, 0, (1 - _lastBrightness) * 0.65),
                ),
              ),
            if (_overlayData != null)
              IgnorePointer(
                child: Center(
                  child:
                      widget.config.overlayBuilder?.call(
                        context,
                        _overlayData!,
                      ) ??
                      _DefaultGestureOverlay(data: _overlayData!),
                ),
              ),
          ],
        );
        if (!widget.config.enabled) {
          return content;
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent event) =>
              _handlePointerDown(event, constraints.biggest),
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: content,
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event, Size size) {
    if (_activePointer != null) {
      return;
    }
    _activePointer = event.pointer;
    _overlayTimer?.cancel();
    _axis = null;
    _activeType = null;
    _pendingSeekPosition = null;
    final currentValue = widget.controller.value;
    _calculator = M3u8GestureDragCalculator(
      size: size,
      startPosition: event.localPosition,
      startPlaybackPosition: currentValue.position,
      duration: currentValue.duration,
      startBrightness: _lastBrightness,
      startVolume: currentValue.volume,
      seekSensitivity: widget.config.seekSensitivity,
      verticalSensitivity: widget.config.verticalSensitivity,
    );
    if (widget.config.brightnessEnabled) {
      unawaited(_refreshStartBrightness(event.localPosition, size));
    }
  }

  Future<void> _refreshStartBrightness(Offset startPosition, Size size) async {
    final brightness = await _safeGetBrightness();
    _lastBrightness = brightness;
    if (!mounted || _axis != null) {
      return;
    }
    final currentValue = widget.controller.value;
    _calculator = M3u8GestureDragCalculator(
      size: size,
      startPosition: startPosition,
      startPlaybackPosition: currentValue.position,
      duration: currentValue.duration,
      startBrightness: brightness,
      startVolume: currentValue.volume,
      seekSensitivity: widget.config.seekSensitivity,
      verticalSensitivity: widget.config.verticalSensitivity,
    );
  }

  Future<void> _handlePointerMove(PointerMoveEvent event) async {
    if (event.pointer != _activePointer) {
      return;
    }
    final calculator = _calculator;
    if (calculator == null) {
      return;
    }
    final delta = event.localPosition - calculator.startPosition;
    _axis ??= calculator.axisFor(delta);
    final axis = _axis;
    if (axis == null) {
      return;
    }
    if (axis == M3u8GestureAxis.horizontal) {
      if (!widget.config.seekEnabled) {
        return;
      }
      final position = calculator.seekPositionFor(delta);
      _pendingSeekPosition = position;
      _showOverlay(
        M3u8GestureOverlayData.seek(
          position: position,
          duration: calculator.duration,
        ),
      );
      _activeType = M3u8GestureControlType.seek;
      return;
    }
    if (calculator.isLeftSide) {
      if (!widget.config.brightnessEnabled) {
        return;
      }
      final brightness = calculator.brightnessFor(delta);
      _lastBrightness = brightness;
      _activeType = M3u8GestureControlType.brightness;
      _showOverlay(M3u8GestureOverlayData.brightness(brightness));
      await M3u8ScreenBrightness.set(brightness);
      return;
    }
    if (!widget.config.volumeEnabled) {
      return;
    }
    final volume = calculator.volumeFor(delta);
    _activeType = M3u8GestureControlType.volume;
    _showOverlay(M3u8GestureOverlayData.volume(volume));
    await widget.controller.setVolume(volume);
  }

  Future<void> _handlePointerUp(PointerUpEvent event) async {
    if (event.pointer != _activePointer) {
      return;
    }
    final pendingSeek = _pendingSeekPosition;
    final activeType = _activeType;
    _resetGesture(keepOverlay: true);
    _activePointer = null;
    if (activeType == null) {
      widget.onTap?.call();
      return;
    }
    if (activeType == M3u8GestureControlType.seek && pendingSeek != null) {
      await widget.controller.seekTo(pendingSeek);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    _activePointer = null;
    _resetGesture();
  }

  void _showOverlay(M3u8GestureOverlayData data) {
    _overlayTimer?.cancel();
    setState(() {
      _overlayData = data;
    });
  }

  void _resetGesture({bool keepOverlay = false}) {
    _calculator = null;
    _axis = null;
    _activeType = null;
    _pendingSeekPosition = null;
    if (keepOverlay) {
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) {
          setState(() {
            _overlayData = null;
          });
        }
      });
      return;
    }
    _overlayTimer?.cancel();
    setState(() {
      _overlayData = null;
    });
  }

  Future<double> _safeGetBrightness() async {
    try {
      return await M3u8ScreenBrightness.get();
    } catch (_) {
      return 0.5;
    }
  }
}

class _DefaultGestureOverlay extends StatelessWidget {
  const _DefaultGestureOverlay({required this.data});

  final M3u8GestureOverlayData data;

  @override
  Widget build(BuildContext context) {
    final icon = switch (data.type) {
      M3u8GestureControlType.brightness => Icons.brightness_6,
      M3u8GestureControlType.volume => Icons.volume_up,
      M3u8GestureControlType.seek => Icons.play_arrow,
    };
    final label = switch (data.type) {
      M3u8GestureControlType.brightness =>
        '${((data.value ?? 0) * 100).round()}%',
      M3u8GestureControlType.volume => '${((data.value ?? 0) * 100).round()}%',
      M3u8GestureControlType.seek =>
        '${_formatDuration(data.position ?? Duration.zero)} / '
            '${_formatDuration(data.duration ?? Duration.zero)}',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    final remainingMinutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    return '$hours:$remainingMinutes:$seconds';
  }
  return '$minutes:$seconds';
}
