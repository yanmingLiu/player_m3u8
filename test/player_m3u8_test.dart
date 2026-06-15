import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8/player_m3u8_platform_interface.dart';
import 'package:player_m3u8/src/m3u8_player_event.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlayerM3u8Platform extends PlayerM3u8Platform
    with MockPlatformInterfaceMixin {
  final StreamController<M3u8PlayerEvent> eventController =
      StreamController<M3u8PlayerEvent>.broadcast();
  final StreamController<M3u8CacheEvent> cacheEventController =
      StreamController<M3u8CacheEvent>.broadcast();

  @override
  Stream<M3u8PlayerEvent> get events => eventController.stream;

  @override
  Stream<M3u8CacheEvent> get cacheEvents => cacheEventController.stream;

  int nextPlayerId = 7;
  int? createdPlayerId;
  M3u8Source? createdSource;
  Duration? initialPosition;
  double? playbackSpeed;
  double? volume;
  bool? isMuted;
  List<M3u8SubtitleTrack>? subtitles;
  String? selectedSubtitleId;
  String? selectedSubtitleCommand;
  String? selectedAudioTrackId;
  int? playedPlayerId;
  int? pausedPlayerId;
  int? disposedPlayerId;
  Duration? seekPosition;
  M3u8Quality? selectedQuality;
  double? selectedPlaybackSpeed;
  double? selectedVolume;
  bool? selectedMuted;
  double brightness = 0.5;
  double? selectedBrightness;
  M3u8RecoveryPolicy? recoveryPolicy;
  int? configuredCacheBytes;
  int? configuredMaxConcurrentPrecacheTasks;
  M3u8CacheInfo cacheInfo = const M3u8CacheInfo(
    maxSizeBytes: 512,
    sizeBytes: 128,
  );
  bool cacheCleared = false;
  M3u8Source? precacheSource;
  Duration? precacheInitialPosition;
  int? precachePriority;
  int? precacheMaxRetries;
  Map<String, Object?>? precacheMetadata;
  String? cancelledPrecacheTaskId;
  String? pausedPrecacheTaskId;
  String? resumedPrecacheTaskId;
  M3u8Source? sourceInfoSource;
  M3u8Source? clearedSourceCache;

  @override
  Future<int> create({
    required M3u8Source source,
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
    List<M3u8SubtitleTrack> subtitles = const <M3u8SubtitleTrack>[],
    String? selectedSubtitleId,
    String? selectedAudioTrackId,
  }) async {
    createdSource = source;
    this.recoveryPolicy = recoveryPolicy;
    this.initialPosition = initialPosition;
    this.playbackSpeed = playbackSpeed;
    this.volume = volume;
    this.isMuted = isMuted;
    this.subtitles = subtitles;
    this.selectedSubtitleId = selectedSubtitleId;
    this.selectedAudioTrackId = selectedAudioTrackId;
    createdPlayerId = nextPlayerId;
    return nextPlayerId++;
  }

  @override
  Future<void> play(int playerId) async {
    playedPlayerId = playerId;
  }

  @override
  Future<void> pause(int playerId) async {
    pausedPlayerId = playerId;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seekPosition = position;
  }

  @override
  Future<void> setQuality(int playerId, M3u8Quality quality) async {
    selectedQuality = quality;
  }

  @override
  Future<void> setRecoveryPolicy(
    int playerId,
    M3u8RecoveryPolicy recoveryPolicy,
  ) async {
    this.recoveryPolicy = recoveryPolicy;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    selectedPlaybackSpeed = speed;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    selectedVolume = volume;
  }

  @override
  Future<void> setMuted(int playerId, bool isMuted) async {
    selectedMuted = isMuted;
  }

  @override
  Future<double> getScreenBrightness() async => brightness;

  @override
  Future<void> setScreenBrightness(double brightness) async {
    selectedBrightness = brightness;
    this.brightness = brightness;
  }

  @override
  Future<void> setSubtitle(int playerId, String? subtitleId) async {
    selectedSubtitleCommand = subtitleId;
  }

  @override
  Future<void> setAudioTrack(int playerId, String? audioTrackId) async {
    selectedAudioTrackId = audioTrackId;
  }

  @override
  Future<void> disposePlayer(int playerId) async {
    disposedPlayerId = playerId;
  }

  @override
  Future<void> configureCache({
    required int maxSizeBytes,
    int maxConcurrentPrecacheTasks = 2,
  }) async {
    configuredCacheBytes = maxSizeBytes;
    configuredMaxConcurrentPrecacheTasks = maxConcurrentPrecacheTasks;
  }

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }

  @override
  Future<M3u8CacheInfo> getCacheInfo() async {
    return cacheInfo;
  }

  @override
  Future<String> precache({
    required M3u8Source source,
    Duration initialPosition = Duration.zero,
    M3u8Quality quality = M3u8Quality.auto,
    int priority = 0,
    int maxRetries = 2,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    precacheSource = source;
    precacheInitialPosition = initialPosition;
    selectedQuality = quality;
    precachePriority = priority;
    precacheMaxRetries = maxRetries;
    precacheMetadata = metadata;
    return 'cache-task-1';
  }

  @override
  Future<void> cancelPrecache(String taskId) async {
    cancelledPrecacheTaskId = taskId;
  }

  @override
  Future<void> pausePrecache(String taskId) async {
    pausedPrecacheTaskId = taskId;
  }

  @override
  Future<void> resumePrecache(String taskId) async {
    resumedPrecacheTaskId = taskId;
  }

  @override
  Future<List<M3u8CacheTask>> cacheTasks() async {
    return const [
      M3u8CacheTask(
        taskId: 'cache-task-1',
        url: 'https://example.com/index.m3u8',
        status: M3u8CacheTaskStatus.running,
      ),
    ];
  }

  @override
  Future<M3u8CacheInfo> sourceCacheInfo(M3u8Source source) async {
    sourceInfoSource = source;
    return cacheInfo;
  }

  @override
  Future<void> clearSourceCache(M3u8Source source) async {
    clearedSourceCache = source;
  }
}

void main() {
  test('parses disk cache event fields', () {
    final event = M3u8PlayerEvent.fromMap(const <Object?, Object?>{
      'playerId': 4,
      'event': 'diskCache',
      'duration': 60000,
      'diskCacheStartPosition': 15000,
      'diskCachePosition': 30000,
      'diskCachePercent': 50.0,
      'isDiskCacheComplete': false,
      'startupTime': 1200,
      'rebufferCount': 2,
      'rebufferDuration': 3400,
      'droppedFrames': 3,
      'videoBitrate': 2200000,
      'observedBitrate': 1800000,
      'qualitySwitchCount': 2,
      'recoveryCount': 1,
      'lastRecoveryReason': 'rebuffer',
      'availableQualities': [
        {
          'id': '1080p',
          'label': '1080p',
          'width': 1920,
          'height': 1080,
          'bitrate': 2200000,
        },
      ],
      'selectedQuality': {'id': 'auto', 'label': 'Auto', 'isAuto': true},
      'diagnostics': {
        'platform': 'android',
        'sessionId': 'session-1',
        'sourceId': 'source-1',
        'sourceType': 'hls',
        'positionMs': 4000,
      },
    });

    expect(event.playerId, 4);
    expect(event.type, M3u8PlayerEventType.diskCache);
    expect(event.duration, const Duration(seconds: 60));
    expect(event.diskCacheStartPosition, const Duration(seconds: 15));
    expect(event.diskCachePosition, const Duration(seconds: 30));
    expect(event.diskCachePercent, 50.0);
    expect(event.isDiskCacheComplete, false);
    expect(event.startupTime, const Duration(milliseconds: 1200));
    expect(event.rebufferCount, 2);
    expect(event.rebufferDuration, const Duration(milliseconds: 3400));
    expect(event.droppedFrames, 3);
    expect(event.videoBitrate, 2200000);
    expect(event.observedBitrate, 1800000);
    expect(event.qualitySwitchCount, 2);
    expect(event.recoveryCount, 1);
    expect(event.lastRecoveryReason, 'rebuffer');
    expect(event.availableQualities, hasLength(1));
    expect(event.availableQualities!.single.height, 1080);
    expect(event.selectedQuality, M3u8Quality.auto);
    expect(event.diagnostics?['sessionId'], 'session-1');
    expect(event.diagnostics?['sourceType'], 'hls');
  });

  test('parses standalone cache event fields', () {
    final event = M3u8CacheEvent.fromMap(const <Object?, Object?>{
      'taskId': 'cache-task-1',
      'url': 'https://example.com/index.m3u8',
      'event': 'completed',
      'duration': 60000,
      'diskCacheStartPosition': 15000,
      'diskCachePosition': 60000,
      'diskCachePercent': 100.0,
      'isDiskCacheComplete': true,
      'quality': {
        'id': '720p',
        'label': '720p',
        'width': 1280,
        'height': 720,
        'bitrate': 1500000,
      },
    });

    expect(event.taskId, 'cache-task-1');
    expect(event.url, 'https://example.com/index.m3u8');
    expect(event.type, M3u8CacheEventType.completed);
    expect(event.duration, const Duration(seconds: 60));
    expect(event.startPosition, const Duration(seconds: 15));
    expect(event.position, const Duration(seconds: 60));
    expect(event.percent, 100.0);
    expect(event.isComplete, true);
    expect(event.quality?.height, 720);
  });

  test('parses extended cache event fields', () {
    final event = M3u8CacheEvent.fromMap(const <Object?, Object?>{
      'playerId': 9,
      'event': 'progress',
      'taskId': 'cache-task-1',
      'url': 'https://example.com/index.m3u8',
      'owner': 'standalone',
      'status': 'running',
      'sourceType': 'hls',
      'priority': 6,
      'duration': 60000,
      'diskCacheStartPosition': 10000,
      'diskCachePosition': 20000,
      'diskCachePercent': 33.3,
      'bytesCached': 1024,
      'bytesTotal': 4096,
      'downloadSpeedBytesPerSecond': 512,
      'cacheHitCount': 2,
      'networkFetchCount': 3,
      'segmentIndex': 4,
      'segmentCount': 12,
      'currentUrl': 'https://example.com/segment.ts',
      'retryCount': 1,
      'updatedAt': 1700000000000,
      'metadata': {'title': 'Episode 1'},
      'quality': {'id': '720p', 'label': '720p', 'height': 720},
    });

    expect(event.playerId, 9);
    expect(event.owner, M3u8CacheEventOwner.standalone);
    expect(event.status, M3u8CacheEventStatus.running);
    expect(event.sourceType, M3u8SourceType.hls);
    expect(event.priority, 6);
    expect(event.bytesCached, 1024);
    expect(event.bytesTotal, 4096);
    expect(event.byteProgress, 0.25);
    expect(event.downloadSpeedBytesPerSecond, 512);
    expect(event.cacheHitCount, 2);
    expect(event.networkFetchCount, 3);
    expect(event.segmentIndex, 4);
    expect(event.segmentCount, 12);
    expect(event.currentUrl, 'https://example.com/segment.ts');
    expect(event.retryCount, 1);
    expect(event.updatedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(event.metadata, {'title': 'Episode 1'});
    expect(event.quality?.height, 720);
  });

  test('parses unsupported HLS cache error event code', () {
    final event = M3u8CacheEvent.fromMap(const <Object?, Object?>{
      'taskId': 'cache-task-unsupported',
      'url': 'https://example.com/live.m3u8',
      'event': 'error',
      'owner': 'standalone',
      'status': 'error',
      'sourceType': 'hls',
      'error': {
        'code': 'unsupported_hls_playlist',
        'message': 'iOS HLS disk precache supports VOD playlists only.',
      },
    });

    expect(event.type, M3u8CacheEventType.error);
    expect(event.status, M3u8CacheEventStatus.error);
    expect(event.error?.code, 'unsupported_hls_playlist');
    expect(event.error?.message, contains('VOD playlists only'));
  });

  test('player event parser handles fallback values and track filtering', () {
    final event = M3u8PlayerEvent.fromMap(const <Object?, Object?>{
      'playerId': 4.2,
      'event': 'error',
      'position': -1,
      'width': 1920,
      'height': 1080,
      'availableQualities': [
        {'height': 480},
        'ignored',
      ],
      'selectedQuality': 'ignored',
      'availableSubtitles': [
        {'id': '', 'label': 'invalid'},
        {'id': 'en', 'label': 'English'},
      ],
      'selectedSubtitle': {'id': '', 'label': 'invalid'},
      'availableAudioTracks': [
        {'id': '', 'label': 'invalid'},
        {'id': 'main', 'label': 'Main'},
      ],
      'selectedAudioTrack': {'id': '', 'label': 'invalid'},
      'error': {'details': 'detail'},
    });

    expect(event.playerId, 4);
    expect(event.type, M3u8PlayerEventType.error);
    expect(event.position, isNull);
    expect(event.size, const Size(1920, 1080));
    expect(event.availableQualities?.single.height, 480);
    expect(event.selectedQuality, isNull);
    expect(event.availableSubtitles?.single.id, 'en');
    expect(event.selectedSubtitle, isNull);
    expect(event.availableAudioTracks?.single.id, 'main');
    expect(event.selectedAudioTrack, isNull);
    expect(event.error?.code, 'player_error');
    expect(event.error?.message, 'Playback failed.');
    expect(event.error?.details, 'detail');

    expect(
      () =>
          M3u8PlayerEvent.fromMap(const <Object?, Object?>{'playerId': 'bad'}),
      throwsArgumentError,
    );
  });

  test('controller initializes and applies player events', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize(
      source: const M3u8Source(
        videoUrl: 'https://example.com/index.m3u8',
        videoHeaders: {'Authorization': 'token'},
      ),
      recoveryPolicy: const M3u8RecoveryPolicy(
        rebufferThreshold: 2,
        minimumRecoveryInterval: Duration(seconds: 5),
        minimumAutoQualityHeight: 480,
      ),
      initialPosition: const Duration(seconds: 12),
      playbackSpeed: 1.25,
      volume: 0.75,
      isMuted: true,
      subtitles: const [
        M3u8SubtitleTrack(
          id: 'en',
          label: 'English',
          language: 'en',
          url: 'https://example.com/en.vtt',
        ),
      ],
      selectedSubtitleId: 'en',
    );

    expect(controller.playerId, 7);
    expect(platform.createdSource?.videoUrl, 'https://example.com/index.m3u8');
    expect(platform.createdSource?.videoHeaders, const {
      'Authorization': 'token',
    });
    expect(platform.createdSource?.sourceType, M3u8SourceType.auto);
    expect(platform.initialPosition, const Duration(seconds: 12));
    expect(platform.playbackSpeed, 1.25);
    expect(platform.volume, 0.75);
    expect(platform.isMuted, true);
    expect(platform.subtitles?.single.id, 'en');
    expect(platform.selectedSubtitleId, 'en');
    expect(platform.recoveryPolicy?.rebufferThreshold, 2);
    expect(
      platform.recoveryPolicy?.minimumRecoveryInterval,
      const Duration(seconds: 5),
    );
    expect(platform.recoveryPolicy?.minimumAutoQualityHeight, 480);

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.initialized,
        duration: Duration(seconds: 120),
        bufferedPosition: Duration(seconds: 10),
        diskCacheStartPosition: Duration.zero,
        diskCachePosition: Duration(seconds: 30),
        startupTime: Duration(milliseconds: 900),
        rebufferCount: 1,
        rebufferDuration: Duration(milliseconds: 1500),
        droppedFrames: 4,
        videoBitrate: 1500000,
        observedBitrate: 1200000,
        qualitySwitchCount: 3,
        playbackSpeed: 1.25,
        volume: 0.75,
        isMuted: true,
        availableSubtitles: [
          M3u8SubtitleTrack(id: 'en', label: 'English', language: 'en'),
        ],
        selectedSubtitle: M3u8SubtitleTrack(
          id: 'en',
          label: 'English',
          language: 'en',
        ),
        subtitleText: 'Hello',
        recoveryCount: 2,
        lastRecoveryReason: 'error:SOURCE',
        availableQualities: [
          M3u8Quality(
            id: '720p',
            label: '720p',
            width: 1280,
            height: 720,
            bitrate: 1500000,
          ),
        ],
        selectedQuality: M3u8Quality.auto,
        diagnostics: {'sessionId': 'session-1', 'sourceType': 'hls'},
        size: Size(1920, 1080),
      ),
    );
    await pumpEventQueue();

    expect(controller.value.isInitialized, true);
    expect(controller.value.duration, const Duration(seconds: 120));
    expect(controller.value.bufferedPosition, const Duration(seconds: 10));
    expect(controller.value.diskCachePosition, const Duration(seconds: 30));
    expect(controller.value.startupTime, const Duration(milliseconds: 900));
    expect(controller.value.rebufferCount, 1);
    expect(
      controller.value.rebufferDuration,
      const Duration(milliseconds: 1500),
    );
    expect(controller.value.droppedFrames, 4);
    expect(controller.value.videoBitrate, 1500000);
    expect(controller.value.observedBitrate, 1200000);
    expect(controller.value.qualitySwitchCount, 3);
    expect(controller.value.playbackSpeed, 1.25);
    expect(controller.value.volume, 0.75);
    expect(controller.value.isMuted, true);
    expect(controller.value.availableSubtitles.single.id, 'en');
    expect(controller.value.selectedSubtitle?.id, 'en');
    expect(controller.value.subtitleText, 'Hello');
    expect(controller.value.recoveryCount, 2);
    expect(controller.value.lastRecoveryReason, 'error:SOURCE');
    expect(controller.value.availableQualities.single.height, 720);
    expect(controller.value.selectedQuality, M3u8Quality.auto);
    expect(controller.value.diagnostics['sessionId'], 'session-1');
    expect(controller.value.diagnostics['sourceType'], 'hls');
    expect(controller.value.size, const Size(1920, 1080));

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.diskCache,
        duration: Duration(seconds: 120),
        diskCacheStartPosition: Duration(seconds: 30),
        diskCachePosition: Duration(seconds: 90),
        isDiskCacheComplete: false,
      ),
    );
    await pumpEventQueue();

    expect(
      controller.value.diskCacheStartPosition,
      const Duration(seconds: 30),
    );
    expect(controller.value.diskCachePosition, const Duration(seconds: 90));
    expect(controller.value.isDiskCacheComplete, false);

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.diskCache,
        diskCachePercent: 50,
        isDiskCacheComplete: false,
      ),
    );
    await pumpEventQueue();

    expect(controller.value.diskCachePosition, const Duration(seconds: 60));
    expect(controller.value.diskCachePercent, 50);

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.playing,
        position: Duration(seconds: 4),
      ),
    );
    await pumpEventQueue();

    expect(controller.value.isPlaying, true);
    expect(controller.value.position, const Duration(seconds: 4));

    await controller.seekTo(const Duration(seconds: 30));
    expect(platform.seekPosition, const Duration(seconds: 30));

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.progress,
        position: Duration(seconds: 110),
        duration: Duration(seconds: 120),
      ),
    );
    await pumpEventQueue();
    await controller.seekBy(const Duration(seconds: 20));
    expect(platform.seekPosition, const Duration(seconds: 120));
    await controller.seekBy(const Duration(seconds: -200));
    expect(platform.seekPosition, Duration.zero);

    await controller.setQuality(controller.value.availableQualities.single);
    expect(platform.selectedQuality?.height, 720);
    expect(controller.value.selectedQuality.height, 720);

    await controller.setRecoveryPolicy(M3u8RecoveryPolicy.disabled);
    expect(controller.recoveryPolicy.isEnabled, false);
    expect(platform.recoveryPolicy, M3u8RecoveryPolicy.disabled);

    await controller.setPlaybackSpeed(1.5);
    expect(platform.selectedPlaybackSpeed, 1.5);
    expect(controller.value.playbackSpeed, 1.5);

    await controller.setVolume(0.4);
    expect(platform.selectedVolume, 0.4);
    expect(controller.value.volume, 0.4);

    await controller.setMuted(false);
    expect(platform.selectedMuted, false);
    expect(controller.value.isMuted, false);

    await controller.clearSubtitle();
    expect(platform.selectedSubtitleCommand, isNull);
    expect(controller.value.selectedSubtitle, isNull);
    expect(controller.value.subtitleText, '');

    controller.dispose();
    await pumpEventQueue();
    expect(platform.disposedPlayerId, 7);
    await platform.eventController.close();
  });

  test(
    'controller applies paused completed buffering audio and default error events',
    () async {
      final platform = FakePlayerM3u8Platform();
      final controller = M3u8PlayerController(platform: platform);
      await controller.initialize(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      );
      platform.eventController.add(
        const M3u8PlayerEvent(
          playerId: 7,
          type: M3u8PlayerEventType.initialized,
          duration: Duration(seconds: 30),
          availableAudioTracks: [M3u8AudioTrack(id: 'main', label: 'Main')],
        ),
      );
      await pumpEventQueue();

      await controller.setAudioTrack('main');
      expect(platform.selectedAudioTrackId, 'main');
      expect(controller.value.selectedAudioTrack?.id, 'main');
      await controller.clearAudioTrack();
      expect(controller.value.selectedAudioTrack, isNull);

      platform.eventController.add(
        const M3u8PlayerEvent(
          playerId: 7,
          type: M3u8PlayerEventType.buffering,
          position: Duration(seconds: 5),
        ),
      );
      await pumpEventQueue();
      expect(controller.value.isBuffering, true);
      expect(controller.value.position, const Duration(seconds: 5));

      platform.eventController.add(
        const M3u8PlayerEvent(
          playerId: 7,
          type: M3u8PlayerEventType.paused,
          position: Duration(seconds: 6),
        ),
      );
      await pumpEventQueue();
      expect(controller.value.isPlaying, false);
      expect(controller.value.isBuffering, false);
      expect(controller.value.position, const Duration(seconds: 6));

      platform.eventController.add(
        const M3u8PlayerEvent(playerId: 7, type: M3u8PlayerEventType.completed),
      );
      await pumpEventQueue();
      expect(controller.value.isCompleted, true);
      expect(controller.value.position, const Duration(seconds: 30));

      platform.eventController.add(
        const M3u8PlayerEvent(playerId: 7, type: M3u8PlayerEventType.error),
      );
      await pumpEventQueue();
      expect(controller.value.hasError, true);
      expect(controller.value.error?.code, 'player_error');

      controller.dispose();
      await platform.eventController.close();
    },
  );

  test('controller guards invalid lifecycle operations', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    expect(controller.source, isNull);
    expect(controller.playbackSpeed, 1.0);
    expect(controller.volume, 1.0);
    expect(controller.isMuted, false);
    expect(controller.isInitialized, false);
    expect(controller.play(), throwsStateError);
    expect(controller.pause(), throwsStateError);
    expect(controller.setQuality(M3u8Quality.auto), throwsStateError);
    expect(controller.retry(), throwsStateError);
    expect(
      () => controller.startQoeSampling(interval: Duration.zero),
      throwsArgumentError,
    );

    await controller.initialize(
      source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
    );
    expect(
      controller.initialize(
        source: M3u8Source(videoUrl: 'https://example.com/again.m3u8'),
      ),
      throwsStateError,
    );
    await controller.setRecoveryPolicy(M3u8RecoveryPolicy.disabled);
    expect(controller.recoveryPolicy, M3u8RecoveryPolicy.disabled);

    controller.dispose();
    expect(controller.play(), throwsStateError);
    await platform.eventController.close();
  });

  test('events for other players are ignored', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);
    await controller.initialize(
      source: M3u8Source(videoUrl: 'https://example.com/one.m3u8'),
    );

    await controller.setSource(
      M3u8Source(
        videoUrl: 'https://example.com/two.mp4',
        sourceType: M3u8SourceType.progressive,
      ),
      autoPlay: true,
      recoveryPolicy: const M3u8RecoveryPolicy(rebufferThreshold: 4),
      initialPosition: const Duration(seconds: 18),
      playbackSpeed: 1.5,
      volume: 0.4,
      isMuted: true,
      subtitles: const [
        M3u8SubtitleTrack(id: 'zh', label: '中文', language: 'zh'),
      ],
      selectedSubtitleId: 'zh',
    );

    expect(platform.disposedPlayerId, 7);
    expect(controller.playerId, 8);
    expect(platform.playedPlayerId, 8);
    expect(platform.createdSource?.videoUrl, 'https://example.com/two.mp4');
    expect(platform.createdSource?.sourceType, M3u8SourceType.progressive);
    expect(platform.initialPosition, const Duration(seconds: 18));
    expect(platform.playbackSpeed, 1.5);
    expect(platform.volume, 0.4);
    expect(platform.isMuted, true);
    expect(platform.subtitles?.single.id, 'zh');
    expect(platform.selectedSubtitleId, 'zh');
    expect(platform.recoveryPolicy?.rebufferThreshold, 4);
    expect(controller.value.isInitialized, false);
    expect(controller.value.duration, Duration.zero);

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.initialized,
        duration: Duration(seconds: 90),
        size: Size(1, 1),
      ),
    );
    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 8,
        type: M3u8PlayerEventType.initialized,
        duration: Duration(seconds: 45),
        size: Size(1280, 720),
      ),
    );
    await pumpEventQueue();

    expect(controller.value.duration, const Duration(seconds: 45));
    expect(controller.value.size, const Size(1280, 720));

    controller.dispose();
    await platform.eventController.close();
  });

  test('initial events emitted during create are applied', () async {
    final platform = _EagerEventPlatform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize(
      source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
    );
    await pumpEventQueue();

    expect(controller.value.isInitialized, true);
    expect(controller.value.size, const Size(1280, 720));
    controller.dispose();
    await platform.eventController.close();
  });

  test('retry recreates last source from current position', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize(
      source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
    );
    platform.eventController.add(
      const M3u8PlayerEvent(playerId: 7, type: M3u8PlayerEventType.playing),
    );
    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.progress,
        position: Duration(seconds: 42),
      ),
    );
    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.error,
        error: M3u8PlayerError(code: 'source', message: 'failed'),
      ),
    );
    await pumpEventQueue();

    expect(controller.value.hasError, true);

    await controller.retry();

    expect(platform.disposedPlayerId, 7);
    expect(controller.playerId, 8);
    expect(platform.createdSource?.videoUrl, 'https://example.com/index.m3u8');
    expect(platform.initialPosition, const Duration(seconds: 42));
    expect(platform.playedPlayerId, 8);
    expect(controller.value.hasError, false);

    controller.dispose();
    await platform.eventController.close();
  });

  test('controller rejects invalid positions and playback speeds', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    expect(
      controller.initialize(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
        initialPosition: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );

    await controller.initialize(
      source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
    );

    expect(
      controller.seekTo(const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
    expect(controller.setPlaybackSpeed(0.1), throwsArgumentError);
    expect(controller.setPlaybackSpeed(2.5), throwsArgumentError);
    expect(controller.setVolume(-0.1), throwsArgumentError);
    expect(controller.setVolume(1.1), throwsArgumentError);

    controller.dispose();
    await platform.eventController.close();
  });

  test('qoe snapshot computes window deltas', () {
    final startedAt = DateTime.utc(2026, 1, 1, 0, 0, 0);
    final endedAt = startedAt.add(const Duration(seconds: 5));
    final previous = const M3u8PlayerValue(
      rebufferCount: 1,
      rebufferDuration: Duration(milliseconds: 500),
      droppedFrames: 2,
      recoveryCount: 1,
      qualitySwitchCount: 1,
    );
    final current = const M3u8PlayerValue(
      isPlaying: true,
      position: Duration(seconds: 30),
      duration: Duration(minutes: 2),
      bufferedPosition: Duration(seconds: 40),
      diskCachePosition: Duration(seconds: 60),
      startupTime: Duration(milliseconds: 900),
      rebufferCount: 3,
      rebufferDuration: Duration(milliseconds: 1500),
      droppedFrames: 7,
      recoveryCount: 2,
      qualitySwitchCount: 4,
      videoBitrate: 1500000,
      observedBitrate: 1200000,
      playbackSpeed: 1.5,
      selectedQuality: M3u8Quality(
        id: '720p',
        label: '720p',
        height: 720,
        bitrate: 1500000,
      ),
    );

    final snapshot = M3u8QoeSnapshot.fromValues(
      playerId: 7,
      startedAt: startedAt,
      endedAt: endedAt,
      previous: previous,
      current: current,
    );

    expect(snapshot.rebufferCountDelta, 2);
    expect(snapshot.rebufferDurationDelta, const Duration(seconds: 1));
    expect(snapshot.rebufferRatio, 0.2);
    expect(snapshot.droppedFramesDelta, 5);
    expect(snapshot.recoveryCountDelta, 1);
    expect(snapshot.qualitySwitchCountDelta, 3);
    expect(snapshot.playbackSpeed, 1.5);
    expect(snapshot.toMap()['selectedQuality'], containsPair('id', '720p'));
    expect(snapshot.toMap()['playbackSpeed'], 1.5);
  });

  test('controller emits qoe snapshots', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);
    final snapshots = <M3u8QoeSnapshot>[];
    final subscription = controller.qoeSnapshots.listen(snapshots.add);

    await controller.initialize(
      source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
    );
    controller.startQoeSampling(emitImmediately: true);
    await pumpEventQueue();

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.progress,
        position: Duration(seconds: 10),
        rebufferCount: 2,
        rebufferDuration: Duration(milliseconds: 900),
        droppedFrames: 4,
        recoveryCount: 1,
        qualitySwitchCount: 2,
      ),
    );
    await pumpEventQueue();
    controller.startQoeSampling(emitImmediately: true);
    await pumpEventQueue();

    expect(snapshots, hasLength(2));
    expect(snapshots.last.playerId, 7);
    expect(snapshots.last.position, const Duration(seconds: 10));
    expect(snapshots.last.rebufferCount, 2);

    controller.dispose();
    await subscription.cancel();
    await platform.eventController.close();
  });

  test('cache wrapper delegates configuration and clear calls', () async {
    final platform = FakePlayerM3u8Platform();

    await M3u8PlayerCache.configure(maxSizeBytes: 128, platform: platform);
    final info = await M3u8PlayerCache.info(platform: platform);
    final taskId = await M3u8PlayerCache.precache(
      M3u8Source(
        videoUrl: 'https://example.com/index.m3u8',
        cacheKey: 'video-1',
      ),
      initialPosition: const Duration(seconds: 12),
      quality: const M3u8Quality(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
        bitrate: 1500000,
      ),
      priority: 7,
      maxRetries: 4,
      metadata: const {'title': 'Episode 1'},
      platform: platform,
    );
    final tasks = await M3u8PlayerCache.tasks(platform: platform);
    final sourceInfo = await M3u8PlayerCache.sourceInfo(
      M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      platform: platform,
    );
    await M3u8PlayerCache.pausePrecache(taskId, platform: platform);
    await M3u8PlayerCache.resumePrecache(taskId, platform: platform);
    await M3u8PlayerCache.clearSource(
      M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      platform: platform,
    );
    await M3u8PlayerCache.cancelPrecache(taskId, platform: platform);
    await M3u8PlayerCache.clear(platform: platform);

    expect(platform.configuredCacheBytes, 128);
    expect(platform.configuredMaxConcurrentPrecacheTasks, 2);
    expect(info.maxSizeBytes, 512);
    expect(info.sizeBytes, 128);
    expect(sourceInfo.sizeBytes, 128);
    expect(tasks.single.taskId, 'cache-task-1');
    expect(info.usageRatio, 0.25);
    expect(taskId, 'cache-task-1');
    expect(platform.precacheSource?.videoUrl, 'https://example.com/index.m3u8');
    expect(platform.precacheSource?.cacheKey, 'video-1');
    expect(platform.precacheSource?.videoHeaders, const {});
    expect(platform.precacheSource?.sourceType, M3u8SourceType.auto);
    expect(platform.precacheInitialPosition, const Duration(seconds: 12));
    expect(platform.selectedQuality?.height, 720);
    expect(platform.precachePriority, 7);
    expect(platform.precacheMaxRetries, 4);
    expect(platform.precacheMetadata, {'title': 'Episode 1'});
    expect(platform.pausedPrecacheTaskId, 'cache-task-1');
    expect(platform.resumedPrecacheTaskId, 'cache-task-1');
    expect(
      platform.clearedSourceCache?.videoUrl,
      'https://example.com/index.m3u8',
    );
    expect(platform.cancelledPrecacheTaskId, 'cache-task-1');
    expect(platform.cacheCleared, true);
    await platform.eventController.close();
    await platform.cacheEventController.close();
  });

  test('cache wrapper rejects invalid cache size', () {
    final platform = FakePlayerM3u8Platform();

    expect(
      () => M3u8PlayerCache.configure(maxSizeBytes: 0, platform: platform),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.precache(
        M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
        initialPosition: const Duration(milliseconds: -1),
        platform: platform,
      ),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.cancelPrecache('', platform: platform),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.configure(
        maxConcurrentPrecacheTasks: 0,
        platform: platform,
      ),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.precache(
        M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
        maxRetries: -1,
        platform: platform,
      ),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.pausePrecache('', platform: platform),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.resumePrecache('', platform: platform),
      throwsArgumentError,
    );
  });

  test('cache wrapper exposes cache events stream', () async {
    final platform = FakePlayerM3u8Platform();
    final events = <M3u8CacheEvent>[];
    final subscription = M3u8PlayerCache.events(
      platform: platform,
    ).listen(events.add);

    platform.cacheEventController.add(
      const M3u8CacheEvent(
        taskId: 'task-1',
        url: 'https://example.com/index.m3u8',
        type: M3u8CacheEventType.progress,
      ),
    );
    await pumpEventQueue();

    expect(events.single.taskId, 'task-1');
    await subscription.cancel();
    await platform.eventController.close();
    await platform.cacheEventController.close();
  });

  test('gesture calculator locks side and clamps values', () {
    const calculator = M3u8GestureDragCalculator(
      size: Size(300, 200),
      startPosition: Offset(50, 100),
      startPlaybackPosition: Duration(seconds: 30),
      duration: Duration(seconds: 100),
      startBrightness: 0.4,
      startVolume: 0.6,
      seekSensitivity: 1,
      verticalSensitivity: 1,
    );

    expect(calculator.isLeftSide, isTrue);
    expect(calculator.brightnessFor(const Offset(0, -400)), 1);
    expect(calculator.volumeFor(const Offset(0, 400)), 0);
    expect(
      calculator.seekPositionFor(const Offset(150, 0)),
      const Duration(seconds: 60),
    );
    expect(calculator.seekPositionFor(const Offset(-300, 0)), Duration.zero);
  });

  testWidgets('gesture controls render child and forward taps', (tester) async {
    final platform = FakePlayerM3u8Platform();
    PlayerM3u8Platform.instance = platform;
    final controller = M3u8PlayerController();
    addTearDown(platform.eventController.close);
    addTearDown(platform.cacheEventController.close);
    addTearDown(controller.dispose);

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: M3u8PlayerGestureControls(
            controller: controller,
            onTap: () {
              tapped = true;
            },
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    );

    expect(find.byType(M3u8PlayerGestureControls), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF000000),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(M3u8PlayerGestureControls));
    expect(tapped, isTrue);
  });

  testWidgets('gesture controls render brightness dimming fallback', (
    tester,
  ) async {
    final platform = FakePlayerM3u8Platform();
    PlayerM3u8Platform.instance = platform;
    final controller = M3u8PlayerController();
    addTearDown(platform.eventController.close);
    addTearDown(platform.cacheEventController.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: M3u8PlayerGestureControls(
            controller: controller,
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromRGBO(0, 0, 0, 0.325),
      ),
      findsOneWidget,
    );
  });
}

class _EagerEventPlatform extends FakePlayerM3u8Platform {
  @override
  Future<int> create({
    required M3u8Source source,
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
    List<M3u8SubtitleTrack> subtitles = const <M3u8SubtitleTrack>[],
    String? selectedSubtitleId,
    String? selectedAudioTrackId,
  }) async {
    final playerId = await super.create(
      source: source,
      recoveryPolicy: recoveryPolicy,
      initialPosition: initialPosition,
      playbackSpeed: playbackSpeed,
      volume: volume,
      isMuted: isMuted,
      subtitles: subtitles,
      selectedSubtitleId: selectedSubtitleId,
      selectedAudioTrackId: selectedAudioTrackId,
    );
    eventController.add(
      M3u8PlayerEvent(
        playerId: playerId,
        type: M3u8PlayerEventType.initialized,
        size: const Size(1280, 720),
      ),
    );
    return playerId;
  }
}
