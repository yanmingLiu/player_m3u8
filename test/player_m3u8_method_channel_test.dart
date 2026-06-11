import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8/player_m3u8_method_channel.dart';
import 'package:player_m3u8/player_m3u8_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('player_m3u8/methods');
  final log = <MethodCall>[];
  final platform = MethodChannelPlayerM3u8();
  Object? Function(MethodCall methodCall)? responseOverride;

  setUp(() {
    log.clear();
    responseOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (responseOverride != null) {
            return responseOverride!(methodCall);
          }
          if (methodCall.method == 'create') {
            return 3;
          }
          if (methodCall.method == 'getCacheInfo') {
            return <String, Object>{
              'maxSizeBytes': 64 * 1024 * 1024,
              'sizeBytes': 16 * 1024 * 1024,
            };
          }
          if (methodCall.method == 'sourceCacheInfo') {
            return <String, Object>{
              'maxSizeBytes': 64 * 1024 * 1024,
              'sizeBytes': 8 * 1024 * 1024,
            };
          }
          if (methodCall.method == 'cacheTasks') {
            return <Object>[
              <String, Object>{
                'taskId': 'cache-task-1',
                'url': 'https://example.com/index.m3u8',
                'status': 'running',
                'bytesCached': 100,
                'bytesTotal': 200,
              },
            ];
          }
          if (methodCall.method == 'precache') {
            return 'cache-task-1';
          }
          return null;
        });
  });

  tearDown(() {
    responseOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'create sends url headers initial position and playback speed',
    () async {
      final playerId = await platform.create(
        source: const M3u8Source(
          videoUrl: 'https://example.com/index.m3u8',
          videoHeaders: {'User-Agent': 'test'},
        ),
        initialPosition: const Duration(seconds: 15),
        playbackSpeed: 1.25,
        volume: 0.75,
        isMuted: true,
        subtitles: const [
          M3u8SubtitleTrack(
            id: 'en',
            label: 'English',
            language: 'en',
            url: 'https://example.com/en.vtt',
            mimeType: 'text/vtt',
          ),
        ],
        selectedSubtitleId: 'en',
      );

      expect(playerId, 3);
      expect(log.single.method, 'create');
      expect(log.single.arguments, {
        'videoUrl': 'https://example.com/index.m3u8',
        'audioUrl': null,
        'videoHeaders': {'User-Agent': 'test'},
        'audioHeaders': {'User-Agent': 'test'},
        'sourceType': 'auto',
        'cacheKey': null,
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
        'subtitles': [
          {
            'id': 'en',
            'label': 'English',
            'language': 'en',
            'url': 'https://example.com/en.vtt',
            'mimeType': 'text/vtt',
            'headers': <String, String>{},
          },
        ],
        'selectedAudioTrackId': null,
        'selectedSubtitleId': 'en',
      });
    },
  );

  test('create sends explicit progressive source type', () async {
    final playerId = await platform.create(
      source: M3u8Source(
        videoUrl: 'https://example.com/video.mp4',
        sourceType: M3u8SourceType.progressive,
      ),
    );

    expect(playerId, 3);
    expect(log.single.method, 'create');
    expect(log.single.arguments, containsPair('sourceType', 'progressive'));
  });

  test('create rejects negative initial position', () {
    expect(
      platform.create(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
        initialPosition: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
  });

  test('create maps null player id and platform errors', () async {
    responseOverride = (_) => null;

    expect(
      platform.create(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(
        isA<PlayerM3u8PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_player_id',
        ),
      ),
    );

    responseOverride = (_) => throw PlatformException(
      code: 'native_error',
      message: 'failed',
      details: const {'reason': 'source'},
    );

    expect(
      platform.create(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(
        isA<PlayerM3u8PlatformException>()
            .having((error) => error.code, 'code', 'native_error')
            .having((error) => error.message, 'message', 'failed')
            .having((error) => error.details, 'details', {'reason': 'source'}),
      ),
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

  test('method calls map platform exceptions', () async {
    responseOverride = (_) =>
        throw PlatformException(code: 'native_error', message: 'failed');

    await expectLater(
      platform.play(3),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.pause(3),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.seekTo(3, Duration.zero),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setQuality(3, M3u8Quality.auto),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setRecoveryPolicy(3, M3u8RecoveryPolicy.defaults),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setPlaybackSpeed(3, 1),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setVolume(3, 1),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setMuted(3, false),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setSubtitle(3, null),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.setAudioTrack(3, null),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.disposePlayer(3),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.configureCache(maxSizeBytes: 1024),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.clearCache(),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.cancelPrecache('task'),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.pausePrecache('task'),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.resumePrecache('task'),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.cacheTasks(),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.sourceCacheInfo(
        M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
    await expectLater(
      platform.clearSourceCache(
        M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(isA<PlayerM3u8PlatformException>()),
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

  test('setSubtitle sends player id and nullable subtitle id', () async {
    await platform.setSubtitle(3, 'en');

    expect(log.single.method, 'setSubtitle');
    expect(log.single.arguments, {'playerId': 3, 'subtitleId': 'en'});

    log.clear();
    await platform.setSubtitle(3, null);
    expect(log.single.arguments, {'playerId': 3, 'subtitleId': null});
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
    await platform.configureCache(
      maxSizeBytes: 64 * 1024 * 1024,
      maxConcurrentPrecacheTasks: 3,
    );

    expect(log.single.method, 'configureCache');
    expect(log.single.arguments, {
      'maxSizeBytes': 64 * 1024 * 1024,
      'maxConcurrentPrecacheTasks': 3,
    });
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

  test('cache info APIs reject null payloads and map errors', () async {
    responseOverride = (_) => null;

    await expectLater(
      platform.getCacheInfo(),
      throwsA(
        isA<PlayerM3u8PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_cache_info',
        ),
      ),
    );
    await expectLater(
      platform.sourceCacheInfo(
        M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(
        isA<PlayerM3u8PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_cache_info',
        ),
      ),
    );

    responseOverride = (_) =>
        throw PlatformException(code: 'cache_error', message: 'failed');

    await expectLater(
      platform.getCacheInfo(),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
  });

  test('precache sends source and returns task id', () async {
    final taskId = await platform.precache(
      source: const M3u8Source(
        videoUrl: 'https://example.com/index.m3u8',
        videoHeaders: {'Authorization': 'token'},
        cacheKey: 'video-1',
      ),
      initialPosition: const Duration(seconds: 15),
      quality: const M3u8Quality(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
        bitrate: 1500000,
      ),
      priority: 8,
      maxRetries: 4,
      metadata: const {'title': 'Episode 1'},
    );

    expect(taskId, 'cache-task-1');
    expect(log.single.method, 'precache');
    expect(log.single.arguments, {
      'videoUrl': 'https://example.com/index.m3u8',
      'audioUrl': null,
      'videoHeaders': {'Authorization': 'token'},
      'audioHeaders': {'Authorization': 'token'},
      'sourceType': 'auto',
      'cacheKey': 'video-1',
      'initialPosition': 15000,
      'quality': {
        'id': '720p',
        'label': '720p',
        'width': 1280,
        'height': 720,
        'bitrate': 1500000,
        'isAuto': false,
      },
      'priority': 8,
      'maxRetries': 4,
      'metadata': {'title': 'Episode 1'},
    });
  });

  test('precache sends explicit HLS source type', () async {
    final taskId = await platform.precache(
      source: M3u8Source(
        videoUrl: 'https://example.com/index.m3u8',
        sourceType: M3u8SourceType.hls,
      ),
    );

    expect(taskId, 'cache-task-1');
    expect(log.single.method, 'precache');
    expect(log.single.arguments, containsPair('sourceType', 'hls'));
  });

  test('precache validates inputs and platform task id', () async {
    expect(
      platform.precache(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
        initialPosition: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(
      platform.precache(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
        maxRetries: -1,
      ),
      throwsArgumentError,
    );

    responseOverride = (_) => '';
    await expectLater(
      platform.precache(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(
        isA<PlayerM3u8PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_cache_task',
        ),
      ),
    );

    responseOverride = (_) => null;
    await expectLater(
      platform.precache(
        source: M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
      ),
      throwsA(isA<PlayerM3u8PlatformException>()),
    );
  });

  test('cancelPrecache sends task id', () async {
    await platform.cancelPrecache('cache-task-1');

    expect(log.single.method, 'cancelPrecache');
    expect(log.single.arguments, {'taskId': 'cache-task-1'});
  });

  test('cache task controls reject empty task ids', () {
    expect(platform.cancelPrecache(' '), throwsArgumentError);
    expect(platform.pausePrecache(' '), throwsArgumentError);
    expect(platform.resumePrecache(' '), throwsArgumentError);
  });

  test('pause and resume precache send task id', () async {
    await platform.pausePrecache('cache-task-1');
    await platform.resumePrecache('cache-task-1');

    expect(log[0].method, 'pausePrecache');
    expect(log[0].arguments, {'taskId': 'cache-task-1'});
    expect(log[1].method, 'resumePrecache');
    expect(log[1].arguments, {'taskId': 'cache-task-1'});
  });

  test('cacheTasks parses task payloads', () async {
    final tasks = await platform.cacheTasks();

    expect(log.single.method, 'cacheTasks');
    expect(tasks.single.taskId, 'cache-task-1');
    expect(tasks.single.status, M3u8CacheTaskStatus.running);
    expect(tasks.single.progress, 0.5);
  });

  test('source cache APIs send source payload', () async {
    const source = M3u8Source(
      videoUrl: 'https://example.com/index.m3u8',
      videoHeaders: {'Authorization': 'token'},
      cacheKey: 'video-1',
    );

    final info = await platform.sourceCacheInfo(source);
    await platform.clearSourceCache(source);

    expect(info.sizeBytes, 8 * 1024 * 1024);
    expect(log[0].method, 'sourceCacheInfo');
    expect(log[0].arguments, containsPair('cacheKey', 'video-1'));
    expect(log[1].method, 'clearSourceCache');
    expect(log[1].arguments, containsPair('cacheKey', 'video-1'));
  });
}
