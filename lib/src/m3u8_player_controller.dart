import 'dart:async';

import 'package:flutter/foundation.dart';

import '../player_m3u8_platform_interface.dart';
import 'm3u8_player_event.dart';
import 'm3u8_player_value.dart';

class M3u8PlayerController extends ValueNotifier<M3u8PlayerValue> {
  M3u8PlayerController({PlayerM3u8Platform? platform})
    : _platform = platform ?? PlayerM3u8Platform.instance,
      super(const M3u8PlayerValue());

  final PlayerM3u8Platform _platform;

  int? _playerId;
  StreamSubscription<M3u8PlayerEvent>? _eventSubscription;
  final List<M3u8PlayerEvent> _pendingEvents = <M3u8PlayerEvent>[];
  bool _disposed = false;
  bool _isChangingSource = false;

  int? get playerId => _playerId;

  bool get isInitialized => _playerId != null && value.isInitialized;

  Future<void> initialize(
    String url, {
    Map<String, String> headers = const <String, String>{},
    bool autoPlay = false,
  }) async {
    _debugAssertNotDisposed();
    if (_playerId != null || _isChangingSource) {
      throw StateError('M3u8PlayerController is already initialized.');
    }
    await _createSource(url, headers: headers, autoPlay: autoPlay);
  }

  Future<void> setSource(
    String url, {
    Map<String, String> headers = const <String, String>{},
    bool autoPlay = false,
  }) async {
    _debugAssertNotDisposed();
    if (_isChangingSource) {
      throw StateError('M3u8PlayerController is already changing source.');
    }
    _isChangingSource = true;
    try {
      final previousPlayerId = _playerId;
      _playerId = null;
      _pendingEvents.clear();
      value = const M3u8PlayerValue();
      if (previousPlayerId != null) {
        await _platform.disposePlayer(previousPlayerId);
      }
      await _createSource(url, headers: headers, autoPlay: autoPlay);
    } finally {
      _isChangingSource = false;
    }
  }

  Future<void> play() async {
    _debugAssertNotDisposed();
    final playerId = _requirePlayerId();
    await _platform.play(playerId);
  }

  Future<void> pause() async {
    _debugAssertNotDisposed();
    final playerId = _requirePlayerId();
    await _platform.pause(playerId);
  }

  Future<void> seekTo(Duration position) async {
    _debugAssertNotDisposed();
    final playerId = _requirePlayerId();
    await _platform.seekTo(playerId, position);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final playerId = _playerId;
    _playerId = null;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    _pendingEvents.clear();
    if (playerId != null) {
      unawaited(_platform.disposePlayer(playerId));
    }
    super.dispose();
  }

  Future<void> _createSource(
    String url, {
    required Map<String, String> headers,
    required bool autoPlay,
  }) async {
    _ensureEventSubscription();
    try {
      final playerId = await _platform.create(url: url, headers: headers);
      _playerId = playerId;
      _flushPendingEventsFor(playerId);
    } catch (_) {
      if (_playerId == null) {
        await _eventSubscription?.cancel();
        _eventSubscription = null;
      }
      rethrow;
    }
    if (autoPlay) {
      await play();
    }
  }

  void _ensureEventSubscription() {
    if (_eventSubscription != null) {
      return;
    }
    _eventSubscription = _platform.events.listen((M3u8PlayerEvent event) {
      final playerId = _playerId;
      if (playerId == null) {
        _pendingEvents.add(event);
      } else if (event.playerId == playerId) {
        _handleEvent(event);
      }
    });
  }

  void _flushPendingEventsFor(int playerId) {
    final pendingEvents = List<M3u8PlayerEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in pendingEvents) {
      if (event.playerId == playerId) {
        _handleEvent(event);
      }
    }
  }

  void _handleEvent(M3u8PlayerEvent event) {
    if (_disposed) {
      return;
    }
    final diskCachePosition = _diskCachePositionFor(event);
    final diskCacheStartPosition = event.diskCacheStartPosition;
    final nextValue = switch (event.type) {
      M3u8PlayerEventType.initialized => value.copyWith(
        isInitialized: true,
        isBuffering: false,
        isCompleted: false,
        duration: event.duration,
        bufferedPosition: event.bufferedPosition,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
        size: event.size,
        error: null,
      ),
      M3u8PlayerEventType.buffering => value.copyWith(
        isBuffering: true,
        position: event.position,
        duration: event.duration,
        bufferedPosition: event.bufferedPosition,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
      ),
      M3u8PlayerEventType.progress => value.copyWith(
        position: event.position,
        duration: event.duration,
        bufferedPosition: event.bufferedPosition,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
      ),
      M3u8PlayerEventType.playing => value.copyWith(
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        position: event.position,
        duration: event.duration,
        bufferedPosition: event.bufferedPosition,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
        error: null,
      ),
      M3u8PlayerEventType.paused => value.copyWith(
        isPlaying: false,
        isBuffering: false,
        position: event.position,
        duration: event.duration,
        bufferedPosition: event.bufferedPosition,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
      ),
      M3u8PlayerEventType.completed => value.copyWith(
        isPlaying: false,
        isBuffering: false,
        isCompleted: true,
        position: event.position ?? value.duration,
        duration: event.duration,
        bufferedPosition: event.bufferedPosition,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
      ),
      M3u8PlayerEventType.diskCache => value.copyWith(
        duration: value.duration == Duration.zero ? event.duration : null,
        diskCacheStartPosition: diskCacheStartPosition,
        diskCachePosition: diskCachePosition,
        diskCachePercent: event.diskCachePercent,
        isDiskCacheComplete: event.isDiskCacheComplete,
      ),
      M3u8PlayerEventType.error => value.copyWith(
        isPlaying: false,
        isBuffering: false,
        error:
            event.error ??
            const M3u8PlayerError(
              code: 'player_error',
              message: 'Playback failed.',
            ),
      ),
    };
    value = nextValue;
  }

  Duration? _diskCachePositionFor(M3u8PlayerEvent event) {
    final diskCachePosition = event.diskCachePosition;
    if (diskCachePosition != null) {
      return diskCachePosition;
    }
    final percent = event.diskCachePercent;
    final durationMs = value.duration.inMilliseconds;
    if (percent == null || durationMs <= 0) {
      return null;
    }
    final normalizedPercent = percent.clamp(0.0, 100.0);
    return Duration(
      milliseconds: (durationMs * normalizedPercent / 100.0).round(),
    );
  }

  int _requirePlayerId() {
    final playerId = _playerId;
    if (playerId == null) {
      throw StateError('M3u8PlayerController has not been initialized.');
    }
    return playerId;
  }

  void _debugAssertNotDisposed() {
    if (_disposed) {
      throw StateError('M3u8PlayerController has been disposed.');
    }
  }
}
