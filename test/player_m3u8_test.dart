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

  int nextPlayerId = 7;
  int? createdPlayerId;
  String? createdUrl;
  Map<String, String>? createdHeaders;
  int? playedPlayerId;
  int? pausedPlayerId;
  int? disposedPlayerId;
  Duration? seekPosition;

  @override
  Stream<M3u8PlayerEvent> get events => eventController.stream;

  @override
  Future<int> create({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) async {
    createdUrl = url;
    createdHeaders = headers;
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
  Future<void> disposePlayer(int playerId) async {
    disposedPlayerId = playerId;
  }
}

void main() {
  test('parses disk cache event fields', () {
    final event = M3u8PlayerEvent.fromMap(const <Object?, Object?>{
      'playerId': 4,
      'event': 'diskCache',
      'duration': 60000,
      'diskCachePosition': 30000,
      'diskCachePercent': 50.0,
      'isDiskCacheComplete': false,
    });

    expect(event.playerId, 4);
    expect(event.type, M3u8PlayerEventType.diskCache);
    expect(event.duration, const Duration(seconds: 60));
    expect(event.diskCachePosition, const Duration(seconds: 30));
    expect(event.diskCachePercent, 50.0);
    expect(event.isDiskCacheComplete, false);
  });

  test('controller initializes and applies player events', () async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);

    await controller.initialize(
      'https://example.com/index.m3u8',
      headers: const {'Authorization': 'token'},
    );

    expect(controller.playerId, 7);
    expect(platform.createdUrl, 'https://example.com/index.m3u8');
    expect(platform.createdHeaders, const {'Authorization': 'token'});

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.initialized,
        duration: Duration(seconds: 120),
        bufferedPosition: Duration(seconds: 10),
        diskCachePosition: Duration(seconds: 30),
        size: Size(1920, 1080),
      ),
    );
    await pumpEventQueue();

    expect(controller.value.isInitialized, true);
    expect(controller.value.duration, const Duration(seconds: 120));
    expect(controller.value.bufferedPosition, const Duration(seconds: 10));
    expect(controller.value.diskCachePosition, const Duration(seconds: 30));
    expect(controller.value.size, const Size(1920, 1080));

    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.diskCache,
        duration: Duration(seconds: 120),
        diskCachePosition: Duration(seconds: 90),
        isDiskCacheComplete: false,
      ),
    );
    await pumpEventQueue();

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

    await controller.setSource('https://example.com/two.m3u8', autoPlay: true);

    expect(platform.disposedPlayerId, 7);
    expect(controller.playerId, 8);
    expect(platform.playedPlayerId, 8);
    expect(platform.createdUrl, 'https://example.com/two.m3u8');
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
}

class _EagerEventPlatform extends FakePlayerM3u8Platform {
  @override
  Future<int> create({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final playerId = await super.create(url: url, headers: headers);
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
