import 'dart:async';

import 'package:flutter/foundation.dart';

import '../player_m3u8_platform_interface.dart';
import 'm3u8_debug_log.dart';
import 'm3u8_audio_track.dart';
import 'm3u8_player_event.dart';
import 'm3u8_player_value.dart';
import 'm3u8_qoe_snapshot.dart';
import 'm3u8_recovery_policy.dart';
import 'm3u8_source.dart';
import 'm3u8_subtitle_track.dart';

class M3u8PlayerController extends ValueNotifier<M3u8PlayerValue> {
  M3u8PlayerController({PlayerM3u8Platform? platform})
    : _platform = platform ?? PlayerM3u8Platform.instance,
      super(const M3u8PlayerValue());

  final PlayerM3u8Platform _platform;

  int? _playerId;
  M3u8RecoveryPolicy _recoveryPolicy = M3u8RecoveryPolicy.defaults;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  StreamSubscription<M3u8PlayerEvent>? _eventSubscription;
  final List<M3u8PlayerEvent> _pendingEvents = <M3u8PlayerEvent>[];
  final StreamController<M3u8QoeSnapshot> _qoeSnapshotController =
      StreamController<M3u8QoeSnapshot>.broadcast();
  Timer? _qoeTimer;
  M3u8PlayerValue _lastQoeValue = const M3u8PlayerValue();
  DateTime? _lastQoeSampleAt;
  M3u8Source? _source;
  List<M3u8SubtitleTrack> _subtitles = const <M3u8SubtitleTrack>[];
  String? _selectedSubtitleId;
  String? _selectedAudioTrackId;
  bool _wasPlayingBeforeLastError = false;
  bool _disposed = false;
  bool _isChangingSource = false;

  int? get playerId => _playerId;

  M3u8RecoveryPolicy get recoveryPolicy => _recoveryPolicy;

  M3u8Source? get source => _source;

  double get playbackSpeed => _playbackSpeed;

  double get volume => _volume;

  bool get isMuted => _isMuted;

  Stream<M3u8QoeSnapshot> get qoeSnapshots => _qoeSnapshotController.stream;

  bool get isInitialized => _playerId != null && value.isInitialized;

  void startQoeSampling({
    Duration interval = const Duration(seconds: 5),
    bool emitImmediately = false,
  }) {
    _debugAssertNotDisposed();
    if (interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Must be greater than zero.',
      );
    }
    stopQoeSampling();
    _lastQoeValue = value;
    _lastQoeSampleAt = DateTime.now();
    if (emitImmediately) {
      _emitQoeSnapshot();
    }
    _qoeTimer = Timer.periodic(interval, (_) => _emitQoeSnapshot());
  }

  void stopQoeSampling() {
    _qoeTimer?.cancel();
    _qoeTimer = null;
    _lastQoeSampleAt = null;
  }

  void _resetQoeBaseline() {
    _lastQoeValue = value;
    if (_qoeTimer != null) {
      _lastQoeSampleAt = DateTime.now();
    }
  }

  Future<void> initialize({
    required M3u8Source source,
    bool autoPlay = false,
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
    List<M3u8SubtitleTrack> subtitles = const <M3u8SubtitleTrack>[],
    String? selectedSubtitleId,
    String? selectedAudioTrackId,
  }) async {
    _debugAssertNotDisposed();
    if (_playerId != null || _isChangingSource) {
      throw StateError('M3u8PlayerController is already initialized.');
    }
    recoveryPolicy.debugAssertValid();
    _debugAssertValidPosition(initialPosition);
    _debugAssertValidPlaybackSpeed(playbackSpeed);
    _debugAssertValidVolume(volume);
    _recoveryPolicy = recoveryPolicy;
    _playbackSpeed = playbackSpeed;
    _volume = volume;
    _isMuted = isMuted;
    _source = source;
    _subtitles = List<M3u8SubtitleTrack>.unmodifiable(subtitles);
    _selectedSubtitleId = selectedSubtitleId;
    _selectedAudioTrackId = selectedAudioTrackId;
    await _createSource(
      source,
      autoPlay: autoPlay,
      initialPosition: initialPosition,
      subtitles: subtitles,
      selectedSubtitleId: selectedSubtitleId,
    );
  }

  Future<void> setSource(
    M3u8Source source, {
    bool autoPlay = false,
    M3u8RecoveryPolicy? recoveryPolicy,
    Duration initialPosition = Duration.zero,
    double? playbackSpeed,
    double? volume,
    bool? isMuted,
    List<M3u8SubtitleTrack> subtitles = const <M3u8SubtitleTrack>[],
    String? selectedSubtitleId,
    String? selectedAudioTrackId,
  }) async {
    _debugAssertNotDisposed();
    _debugAssertValidPosition(initialPosition);
    if (playbackSpeed != null) {
      _debugAssertValidPlaybackSpeed(playbackSpeed);
    }
    if (volume != null) {
      _debugAssertValidVolume(volume);
    }
    if (_isChangingSource) {
      throw StateError('M3u8PlayerController is already changing source.');
    }
    _isChangingSource = true;
    try {
      final previousPlayerId = _playerId;
      _playerId = null;
      _pendingEvents.clear();
      value = const M3u8PlayerValue();
      _resetQoeBaseline();
      if (recoveryPolicy != null) {
        recoveryPolicy.debugAssertValid();
        _recoveryPolicy = recoveryPolicy;
      }
      if (playbackSpeed != null) {
        _playbackSpeed = playbackSpeed;
      }
      if (volume != null) {
        _volume = volume;
      }
      if (isMuted != null) {
        _isMuted = isMuted;
      }
      if (previousPlayerId != null) {
        await _platform.disposePlayer(previousPlayerId);
      }
      _source = source;
      _subtitles = List<M3u8SubtitleTrack>.unmodifiable(subtitles);
      _selectedSubtitleId = selectedSubtitleId;
      _selectedAudioTrackId = selectedAudioTrackId;
      await _createSource(
        source,
        autoPlay: autoPlay,
        initialPosition: initialPosition,
        subtitles: subtitles,
        selectedSubtitleId: selectedSubtitleId,
      );
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
    _debugAssertValidPosition(position);
    final playerId = _requirePlayerId();
    await _platform.seekTo(playerId, position);
  }

  Future<void> seekBy(Duration offset) {
    _debugAssertNotDisposed();
    final duration = value.duration;
    final target = value.position + offset;
    if (target <= Duration.zero) {
      return seekTo(Duration.zero);
    }
    if (duration > Duration.zero && target > duration) {
      return seekTo(duration);
    }
    return seekTo(target);
  }

  Future<void> setQuality(M3u8Quality quality) async {
    _debugAssertNotDisposed();
    final playerId = _requirePlayerId();
    await _platform.setQuality(playerId, quality);
    value = value.copyWith(selectedQuality: quality);
  }

  Future<void> setRecoveryPolicy(M3u8RecoveryPolicy recoveryPolicy) async {
    _debugAssertNotDisposed();
    recoveryPolicy.debugAssertValid();
    _recoveryPolicy = recoveryPolicy;
    final playerId = _playerId;
    if (playerId != null) {
      await _platform.setRecoveryPolicy(playerId, recoveryPolicy);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _debugAssertNotDisposed();
    _debugAssertValidPlaybackSpeed(speed);
    _playbackSpeed = speed;
    final playerId = _requirePlayerId();
    await _platform.setPlaybackSpeed(playerId, speed);
    value = value.copyWith(playbackSpeed: speed);
  }

  Future<void> setVolume(double volume) async {
    _debugAssertNotDisposed();
    _debugAssertValidVolume(volume);
    _volume = volume;
    final playerId = _requirePlayerId();
    await _platform.setVolume(playerId, volume);
    value = value.copyWith(volume: volume);
  }

  Future<void> setMuted(bool isMuted) async {
    _debugAssertNotDisposed();
    _isMuted = isMuted;
    final playerId = _requirePlayerId();
    await _platform.setMuted(playerId, isMuted);
    value = value.copyWith(isMuted: isMuted);
  }

  Future<void> setSubtitle(String? subtitleId) async {
    _debugAssertNotDisposed();
    final playerId = _requirePlayerId();
    await _platform.setSubtitle(playerId, subtitleId);
    _selectedSubtitleId = subtitleId;
    M3u8SubtitleTrack? selectedSubtitle;
    if (subtitleId != null) {
      for (final track in value.availableSubtitles) {
        if (track.id == subtitleId) {
          selectedSubtitle = track;
          break;
        }
      }
    }
    value = value.copyWith(
      selectedSubtitle: selectedSubtitle,
      subtitleText: subtitleId == null ? '' : null,
    );
  }

  Future<void> clearSubtitle() => setSubtitle(null);

  Future<void> setAudioTrack(String? audioTrackId) async {
    _debugAssertNotDisposed();
    final playerId = _requirePlayerId();
    await _platform.setAudioTrack(playerId, audioTrackId);
    _selectedAudioTrackId = audioTrackId;
    M3u8AudioTrack? selectedAudioTrack;
    if (audioTrackId != null) {
      for (final track in value.availableAudioTracks) {
        if (track.id == audioTrackId) {
          selectedAudioTrack = track;
          break;
        }
      }
    }
    value = value.copyWith(selectedAudioTrack: selectedAudioTrack);
  }

  Future<void> clearAudioTrack() => setAudioTrack(null);

  Future<void> retry({bool? autoPlay, Duration? initialPosition}) async {
    _debugAssertNotDisposed();
    final source = _source;
    if (source == null) {
      throw StateError('M3u8PlayerController has no source to retry.');
    }
    if (_isChangingSource) {
      throw StateError('M3u8PlayerController is already changing source.');
    }
    final retryPosition = initialPosition ?? value.position;
    final shouldResumePlayback = value.isPlaying || _wasPlayingBeforeLastError;
    _debugAssertValidPosition(retryPosition);
    _isChangingSource = true;
    try {
      final previousPlayerId = _playerId;
      _playerId = null;
      _pendingEvents.clear();
      value = value.copyWith(
        isInitialized: false,
        isPlaying: false,
        isBuffering: true,
        isCompleted: false,
        error: null,
      );
      _resetQoeBaseline();
      if (previousPlayerId != null) {
        await _platform.disposePlayer(previousPlayerId);
      }
      await _createSource(
        source,
        autoPlay: autoPlay ?? shouldResumePlayback,
        initialPosition: retryPosition,
        subtitles: _subtitles,
        selectedSubtitleId: _selectedSubtitleId,
      );
    } finally {
      _isChangingSource = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    stopQoeSampling();
    final playerId = _playerId;
    _playerId = null;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    _pendingEvents.clear();
    unawaited(_qoeSnapshotController.close());
    if (playerId != null) {
      unawaited(_platform.disposePlayer(playerId));
    }
    super.dispose();
  }

  Future<void> _createSource(
    M3u8Source source, {
    required bool autoPlay,
    required Duration initialPosition,
    required List<M3u8SubtitleTrack> subtitles,
    required String? selectedSubtitleId,
  }) async {
    _ensureEventSubscription();
    try {
      final playerId = await _platform.create(
        source: source,
        recoveryPolicy: _recoveryPolicy,
        initialPosition: initialPosition,
        playbackSpeed: _playbackSpeed,
        volume: _volume,
        isMuted: _isMuted,
        subtitles: subtitles,
        selectedSubtitleId: selectedSubtitleId,
        selectedAudioTrackId: _selectedAudioTrackId,
      );
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
      M3u8PlayerEventType.initialized => _copyWithEventMetrics(
        event,
        value.copyWith(
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
      ),
      M3u8PlayerEventType.buffering => _copyWithEventMetrics(
        event,
        value.copyWith(
          isBuffering: true,
          position: event.position,
          duration: event.duration,
          bufferedPosition: event.bufferedPosition,
          diskCacheStartPosition: diskCacheStartPosition,
          diskCachePosition: diskCachePosition,
          diskCachePercent: event.diskCachePercent,
          isDiskCacheComplete: event.isDiskCacheComplete,
        ),
      ),
      M3u8PlayerEventType.progress => _copyWithEventMetrics(
        event,
        value.copyWith(
          position: event.position,
          duration: event.duration,
          bufferedPosition: event.bufferedPosition,
          diskCacheStartPosition: diskCacheStartPosition,
          diskCachePosition: diskCachePosition,
          diskCachePercent: event.diskCachePercent,
          isDiskCacheComplete: event.isDiskCacheComplete,
        ),
      ),
      M3u8PlayerEventType.playing => _copyWithEventMetrics(
        event,
        value.copyWith(
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
      ),
      M3u8PlayerEventType.paused => _copyWithEventMetrics(
        event,
        value.copyWith(
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
      ),
      M3u8PlayerEventType.completed => _copyWithEventMetrics(
        event,
        value.copyWith(
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
      ),
      M3u8PlayerEventType.diskCache => _copyWithEventMetrics(
        event,
        value.copyWith(
          duration: value.duration == Duration.zero ? event.duration : null,
          diskCacheStartPosition: diskCacheStartPosition,
          diskCachePosition: diskCachePosition,
          diskCachePercent: event.diskCachePercent,
          isDiskCacheComplete: event.isDiskCacheComplete,
        ),
      ),
      M3u8PlayerEventType.error => _copyWithEventMetrics(
        event,
        value.copyWith(
          isPlaying: false,
          isBuffering: false,
          error:
              event.error ??
              const M3u8PlayerError(
                code: 'player_error',
                message: 'Playback failed.',
              ),
        ),
      ),
    };
    if (event.type == M3u8PlayerEventType.error) {
      debugLogPlayerError(
        context: 'playback',
        error:
            event.error ??
            const M3u8PlayerError(
              code: 'player_error',
              message: 'Playback failed.',
            ),
        diagnostics: event.diagnostics ?? const <String, Object?>{},
      );
      _wasPlayingBeforeLastError = value.isPlaying;
    } else if (event.type == M3u8PlayerEventType.playing ||
        event.type == M3u8PlayerEventType.paused ||
        event.type == M3u8PlayerEventType.initialized) {
      _wasPlayingBeforeLastError = false;
    }
    value = nextValue;
  }

  void _emitQoeSnapshot() {
    if (_disposed || _qoeSnapshotController.isClosed) {
      return;
    }
    final playerId = _playerId;
    if (playerId == null) {
      _lastQoeValue = value;
      _lastQoeSampleAt = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final startedAt = _lastQoeSampleAt ?? now;
    final snapshot = M3u8QoeSnapshot.fromValues(
      playerId: playerId,
      startedAt: startedAt,
      endedAt: now,
      previous: _lastQoeValue,
      current: value,
    );
    _lastQoeValue = value;
    _lastQoeSampleAt = now;
    _qoeSnapshotController.add(snapshot);
  }

  M3u8PlayerValue _copyWithEventMetrics(
    M3u8PlayerEvent event,
    M3u8PlayerValue base,
  ) {
    return base.copyWith(
      startupTime: event.startupTime,
      rebufferCount: event.rebufferCount,
      rebufferDuration: event.rebufferDuration,
      droppedFrames: event.droppedFrames,
      videoBitrate: event.videoBitrate,
      observedBitrate: event.observedBitrate,
      qualitySwitchCount: event.qualitySwitchCount,
      availableQualities: event.availableQualities,
      selectedQuality: event.selectedQuality,
      playbackSpeed: event.playbackSpeed,
      volume: event.volume,
      isMuted: event.isMuted,
      availableSubtitles: event.availableSubtitles,
      selectedSubtitle: event.selectedSubtitle,
      subtitleText: event.subtitleText,
      availableAudioTracks: event.availableAudioTracks,
      selectedAudioTrack: event.selectedAudioTrack,
      recoveryCount: event.recoveryCount,
      lastRecoveryReason: event.lastRecoveryReason,
      diagnostics: event.diagnostics,
    );
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

  void _debugAssertValidPosition(Duration position) {
    if (position < Duration.zero) {
      throw ArgumentError.value(
        position,
        'position',
        'Must be greater than or equal to zero.',
      );
    }
  }

  void _debugAssertValidPlaybackSpeed(double speed) {
    if (speed < 0.25 || speed > 2.0 || speed.isNaN || speed.isInfinite) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Must be finite and between 0.25 and 2.0.',
      );
    }
  }

  void _debugAssertValidVolume(double volume) {
    if (volume < 0 || volume > 1 || volume.isNaN || volume.isInfinite) {
      throw ArgumentError.value(
        volume,
        'volume',
        'Must be finite and between 0.0 and 1.0.',
      );
    }
  }
}
