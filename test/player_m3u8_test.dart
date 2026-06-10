import 'dart:async';
import 'dart:ui';

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

  int nextPlayerId = 7;
  int? createdPlayerId;
  String? createdUrl;
  Map<String, String>? createdHeaders;
  Duration? initialPosition;
  double? playbackSpeed;
  double? volume;
  bool? isMuted;
  int? playedPlayerId;
  int? pausedPlayerId;
  int? disposedPlayerId;
  Duration? seekPosition;
  M3u8Quality? selectedQuality;
  double? selectedPlaybackSpeed;
  double? selectedVolume;
  bool? selectedMuted;
  M3u8RecoveryPolicy? recoveryPolicy;
  int? configuredCacheBytes;
  M3u8CacheInfo cacheInfo = const M3u8CacheInfo(
    maxSizeBytes: 512,
    sizeBytes: 128,
  );
  bool cacheCleared = false;
  String? precacheUrl;
  Map<String, String>? precacheHeaders;
  Duration? precacheInitialPosition;
  String? cancelledPrecacheTaskId;

  @override
  Stream<M3u8PlayerEvent> get events => eventController.stream;

  @override
  Stream<M3u8CacheEvent> get cacheEvents => cacheEventController.stream;

  @override
  Future<int> create({
    required String url,
    Map<String, String> headers = const <String, String>{},
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
  }) async {
    createdUrl = url;
    createdHeaders = headers;
    this.recoveryPolicy = recoveryPolicy;
    this.initialPosition = initialPosition;
    this.playbackSpeed = playbackSpeed;
    this.volume = volume;
    this.isMuted = isMuted;
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
  Future<void> disposePlayer(int playerId) async {
    disposedPlayerId = playerId;
  }

  @override
  Future<void> configureCache({required int maxSizeBytes}) async {
    configuredCacheBytes = maxSizeBytes;
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
    required String url,
    Map<String, String> headers = const <String, String>{},
    Duration initialPosition = Duration.zero,
    M3u8Quality quality = M3u8Quality.auto,
  }) async {
    precacheUrl = url;
    precacheHeaders = headers;
    precacheInitialPosition = initialPosition;
    selectedQuality = quality;
    return 'cache-task-1';
  }

  @override
  Future<void> cancelPrecache(String taskId) async {
    cancelledPrecacheTaskId = taskId;
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

  test('controller initializes and applies player events', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize(
      'https://example.com/index.m3u8',
      headers: const {'Authorization': 'token'},
      recoveryPolicy: const M3u8RecoveryPolicy(
        rebufferThreshold: 2,
        minimumRecoveryInterval: Duration(seconds: 5),
        minimumAutoQualityHeight: 480,
      ),
      initialPosition: const Duration(seconds: 12),
      playbackSpeed: 1.25,
      volume: 0.75,
      isMuted: true,
    );

    expect(controller.playerId, 7);
    expect(platform.createdUrl, 'https://example.com/index.m3u8');
    expect(platform.createdHeaders, const {'Authorization': 'token'});
    expect(platform.initialPosition, const Duration(seconds: 12));
    expect(platform.playbackSpeed, 1.25);
    expect(platform.volume, 0.75);
    expect(platform.isMuted, true);
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
    expect(controller.value.recoveryCount, 2);
    expect(controller.value.lastRecoveryReason, 'error:SOURCE');
    expect(controller.value.availableQualities.single.height, 720);
    expect(controller.value.selectedQuality, M3u8Quality.auto);
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

    controller.dispose();
    await pumpEventQueue();
    expect(platform.disposedPlayerId, 7);
    await platform.eventController.close();
  });

  test('events for other players are ignored', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);
    await controller.initialize('https://example.com/index.m3u8');

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 8,
        type: M3u8PlayerEventType.initialized,
        size: Size(1, 1),
      ),
    );
    await pumpEventQueue();

    expect(controller.value.isInitialized, false);
    controller.dispose();
    await platform.eventController.close();
  });

  test('setSource disposes previous player and ignores stale events', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize('https://example.com/one.m3u8');
    expect(controller.playerId, 7);

    await controller.setRecoveryPolicy(
      const M3u8RecoveryPolicy(rebufferThreshold: 4),
    );

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.initialized,
        duration: Duration(seconds: 30),
        size: Size(1920, 1080),
      ),
    );
    await pumpEventQueue();
    expect(controller.value.isInitialized, true);

    await controller.setSource(
      'https://example.com/two.m3u8',
      autoPlay: true,
      initialPosition: const Duration(seconds: 18),
      playbackSpeed: 1.5,
      volume: 0.4,
      isMuted: true,
    );

    expect(platform.disposedPlayerId, 7);
    expect(controller.playerId, 8);
    expect(platform.playedPlayerId, 8);
    expect(platform.createdUrl, 'https://example.com/two.m3u8');
    expect(platform.initialPosition, const Duration(seconds: 18));
    expect(platform.playbackSpeed, 1.5);
    expect(platform.volume, 0.4);
    expect(platform.isMuted, true);
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

    await controller.initialize('https://example.com/index.m3u8');
    await pumpEventQueue();

    expect(controller.value.isInitialized, true);
    expect(controller.value.size, const Size(1280, 720));
    controller.dispose();
    await platform.eventController.close();
  });

  test('retry recreates last source from current position', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize('https://example.com/index.m3u8');
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

    await controller.retry(autoPlay: true);

    expect(platform.disposedPlayerId, 7);
    expect(controller.playerId, 8);
    expect(platform.createdUrl, 'https://example.com/index.m3u8');
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
        'https://example.com/index.m3u8',
        initialPosition: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );

    await controller.initialize('https://example.com/index.m3u8');

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

    await controller.initialize('https://example.com/index.m3u8');
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
      'https://example.com/index.m3u8',
      headers: const {'Authorization': 'token'},
      initialPosition: const Duration(seconds: 12),
      quality: const M3u8Quality(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
        bitrate: 1500000,
      ),
      platform: platform,
    );
    await M3u8PlayerCache.cancelPrecache(taskId, platform: platform);
    await M3u8PlayerCache.clear(platform: platform);

    expect(platform.configuredCacheBytes, 128);
    expect(info.maxSizeBytes, 512);
    expect(info.sizeBytes, 128);
    expect(info.usageRatio, 0.25);
    expect(taskId, 'cache-task-1');
    expect(platform.precacheUrl, 'https://example.com/index.m3u8');
    expect(platform.precacheHeaders, const {'Authorization': 'token'});
    expect(platform.precacheInitialPosition, const Duration(seconds: 12));
    expect(platform.selectedQuality?.height, 720);
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
      () => M3u8PlayerCache.precache('', platform: platform),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.precache(
        'https://example.com/index.m3u8',
        initialPosition: const Duration(milliseconds: -1),
        platform: platform,
      ),
      throwsArgumentError,
    );
    expect(
      () => M3u8PlayerCache.cancelPrecache('', platform: platform),
      throwsArgumentError,
    );
  });
}

class _EagerEventPlatform extends FakePlayerM3u8Platform {
  @override
  Future<int> create({
    required String url,
    Map<String, String> headers = const <String, String>{},
    M3u8RecoveryPolicy recoveryPolicy = M3u8RecoveryPolicy.defaults,
    Duration initialPosition = Duration.zero,
    double playbackSpeed = 1.0,
    double volume = 1.0,
    bool isMuted = false,
  }) async {
    final playerId = await super.create(
      url: url,
      headers: headers,
      recoveryPolicy: recoveryPolicy,
      initialPosition: initialPosition,
      playbackSpeed: playbackSpeed,
      volume: volume,
      isMuted: isMuted,
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
