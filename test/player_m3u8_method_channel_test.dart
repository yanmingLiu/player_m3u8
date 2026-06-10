import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8/player_m3u8_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('player_m3u8/methods');
  final log = <MethodCall>[];
  final platform = MethodChannelPlayerM3u8();

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'create') {
            return 3;
          }
          if (methodCall.method == 'getCacheInfo') {
            return <String, Object>{
              'maxSizeBytes': 64 * 1024 * 1024,
              'sizeBytes': 16 * 1024 * 1024,
            };
          }
          if (methodCall.method == 'precache') {
            return 'cache-task-1';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'create sends url headers initial position and playback speed',
    () async {
      final playerId = await platform.create(
        url: 'https://example.com/index.m3u8',
        headers: const {'User-Agent': 'test'},
        initialPosition: const Duration(seconds: 15),
        playbackSpeed: 1.25,
        volume: 0.75,
        isMuted: true,
      );

      expect(playerId, 3);
      expect(log.single.method, 'create');
      expect(log.single.arguments, {
        'url': 'https://example.com/index.m3u8',
        'headers': {'User-Agent': 'test'},
        'sourceType': 'auto',
        'recoveryPolicy': {
          'isEnabled': true,
          'rebufferThreshold': 3,
          'minimumRecoveryIntervalMs': 10000,
          'minimumAutoQualityHeight': 0,
        },
        'initialPosition': 15000,
        'playbackSpeed': 1.25,
        'volume': 0.75,
        'isMuted': true,
      });
    },
  );

  test('create sends explicit progressive source type', () async {
    final playerId = await platform.create(
      url: 'https://example.com/video.mp4',
      sourceType: M3u8SourceType.progressive,
    );

    expect(playerId, 3);
    expect(log.single.method, 'create');
    expect(log.single.arguments, containsPair('sourceType', 'progressive'));
  });

  test('create rejects negative initial position', () {
    expect(
      platform.create(
        url: 'https://example.com/index.m3u8',
        initialPosition: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
  });

  test('seekTo sends player id and position milliseconds', () async {
    await platform.seekTo(3, const Duration(seconds: 8));

    expect(log.single.method, 'seekTo');
    expect(log.single.arguments, {'playerId': 3, 'position': 8000});
  });

  test('seekTo rejects negative position', () {
    expect(
      platform.seekTo(3, const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });

  test('setPlaybackSpeed sends player id and speed', () async {
    await platform.setPlaybackSpeed(3, 1.5);

    expect(log.single.method, 'setPlaybackSpeed');
    expect(log.single.arguments, {'playerId': 3, 'speed': 1.5});
  });

  test('setPlaybackSpeed rejects invalid speed', () {
    expect(platform.setPlaybackSpeed(3, 0.1), throwsArgumentError);
    expect(platform.setPlaybackSpeed(3, 2.5), throwsArgumentError);
  });

  test('setVolume sends player id and volume', () async {
    await platform.setVolume(3, 0.4);

    expect(log.single.method, 'setVolume');
    expect(log.single.arguments, {'playerId': 3, 'volume': 0.4});
  });

  test('setVolume rejects invalid volume', () {
    expect(platform.setVolume(3, -0.1), throwsArgumentError);
    expect(platform.setVolume(3, 1.1), throwsArgumentError);
  });

  test('setMuted sends player id and muted flag', () async {
    await platform.setMuted(3, true);

    expect(log.single.method, 'setMuted');
    expect(log.single.arguments, {'playerId': 3, 'isMuted': true});
  });

  test('setQuality sends player id and quality payload', () async {
    await platform.setQuality(
      3,
      const M3u8Quality(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
        bitrate: 1500000,
      ),
    );

    expect(log.single.method, 'setQuality');
    expect(log.single.arguments, {
      'playerId': 3,
      'quality': {
        'id': '720p',
        'label': '720p',
        'width': 1280,
        'height': 720,
        'bitrate': 1500000,
        'isAuto': false,
      },
    });
  });

  test('setRecoveryPolicy sends player id and policy payload', () async {
    await platform.setRecoveryPolicy(
      3,
      const M3u8RecoveryPolicy(
        isEnabled: false,
        rebufferThreshold: 2,
        minimumRecoveryInterval: Duration(seconds: 5),
        minimumAutoQualityHeight: 480,
      ),
    );

    expect(log.single.method, 'setRecoveryPolicy');
    expect(log.single.arguments, {
      'playerId': 3,
      'recoveryPolicy': {
        'isEnabled': false,
        'rebufferThreshold': 2,
        'minimumRecoveryIntervalMs': 5000,
        'minimumAutoQualityHeight': 480,
      },
    });
  });

  test('dispose sends player id', () async {
    await platform.disposePlayer(3);

    expect(log.single.method, 'dispose');
    expect(log.single.arguments, {'playerId': 3});
  });

  test('configureCache sends maximum cache size', () async {
    await platform.configureCache(maxSizeBytes: 64 * 1024 * 1024);

    expect(log.single.method, 'configureCache');
    expect(log.single.arguments, {'maxSizeBytes': 64 * 1024 * 1024});
  });

  test('clearCache sends cache clear command', () async {
    await platform.clearCache();

    expect(log.single.method, 'clearCache');
    expect(log.single.arguments, isNull);
  });

  test('getCacheInfo parses cache usage payload', () async {
    final info = await platform.getCacheInfo();

    expect(log.single.method, 'getCacheInfo');
    expect(log.single.arguments, isNull);
    expect(info.maxSizeBytes, 64 * 1024 * 1024);
    expect(info.sizeBytes, 16 * 1024 * 1024);
    expect(info.usageRatio, 0.25);
    expect(info.toMap(), {
      'maxSizeBytes': 64 * 1024 * 1024,
      'sizeBytes': 16 * 1024 * 1024,
    });
  });

  test('precache sends source and returns task id', () async {
    final taskId = await platform.precache(
      url: 'https://example.com/index.m3u8',
      headers: const {'Authorization': 'token'},
      initialPosition: const Duration(seconds: 15),
      quality: const M3u8Quality(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
        bitrate: 1500000,
      ),
    );

    expect(taskId, 'cache-task-1');
    expect(log.single.method, 'precache');
    expect(log.single.arguments, {
      'url': 'https://example.com/index.m3u8',
      'headers': {'Authorization': 'token'},
      'sourceType': 'auto',
      'initialPosition': 15000,
      'quality': {
        'id': '720p',
        'label': '720p',
        'width': 1280,
        'height': 720,
        'bitrate': 1500000,
        'isAuto': false,
      },
    });
  });

  test('precache sends explicit HLS source type', () async {
    final taskId = await platform.precache(
      url: 'https://example.com/index.m3u8',
      sourceType: M3u8SourceType.hls,
    );

    expect(taskId, 'cache-task-1');
    expect(log.single.method, 'precache');
    expect(log.single.arguments, containsPair('sourceType', 'hls'));
  });

  test('cancelPrecache sends task id', () async {
    await platform.cancelPrecache('cache-task-1');

    expect(log.single.method, 'cancelPrecache');
    expect(log.single.arguments, {'taskId': 'cache-task-1'});
  });
}
