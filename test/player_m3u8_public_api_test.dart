import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8/player_m3u8_platform_interface.dart';
import 'package:player_m3u8/src/m3u8_player_event.dart';

import 'player_m3u8_test.dart' show FakePlayerM3u8Platform;

void main() {
  test('source maps headers source type equality and string output', () {
    final source = M3u8Source.fromMap(const <Object?, Object?>{
      'videoUrl': 'https://example.com/video.m3u8',
      'audioUrl': 'https://example.com/audio.m3u8',
      'videoHeaders': {'Authorization': 'video'},
      'audioHeaders': {'Authorization': 'audio'},
      'sourceType': 'hls',
      'cacheKey': 'episode-1',
    });

    expect(source.videoUrl, 'https://example.com/video.m3u8');
    expect(source.audioUrl, 'https://example.com/audio.m3u8');
    expect(source.videoHeaders, {'Authorization': 'video'});
    expect(source.audioHeaders, {'Authorization': 'audio'});
    expect(source.effectiveAudioHeaders, {'Authorization': 'audio'});
    expect(source.sourceType, M3u8SourceType.hls);
    expect(source.toMap(), {
      'videoUrl': 'https://example.com/video.m3u8',
      'audioUrl': 'https://example.com/audio.m3u8',
      'videoHeaders': {'Authorization': 'video'},
      'audioHeaders': {'Authorization': 'audio'},
      'sourceType': 'hls',
      'cacheKey': 'episode-1',
    });
    expect(source, equals(source));
    expect(source, isNot(equals(source.toMap())));
    expect(source.hashCode, isA<int>());
    expect(source.toString(), contains('episode-1'));

    const fallback = M3u8Source(
      videoUrl: 'https://example.com/video.m3u8',
      videoHeaders: {'Authorization': 'video'},
    );
    expect(fallback.effectiveAudioHeaders, {'Authorization': 'video'});
    expect(
      M3u8Source.fromMap(const <Object?, Object?>{}).toMap(),
      containsPair('sourceType', 'auto'),
    );
  });

  test('audio and subtitle tracks map equality fallback and string output', () {
    final audio = M3u8AudioTrack.fromMap(const <Object?, Object?>{
      'id': 'en',
      'language': 'en',
      'url': 'https://example.com/en.m3u8',
      'mimeType': 'application/x-mpegURL',
      'headers': {'Authorization': 'token'},
    });
    final subtitle = M3u8SubtitleTrack.fromMap(const <Object?, Object?>{
      'id': 'zh',
      'language': 'zh',
      'url': 'https://example.com/zh.vtt',
      'mimeType': 'text/vtt',
      'headers': {'Cookie': 'a=b'},
    });

    expect(audio.label, 'en');
    expect(audio.toMap(), {
      'id': 'en',
      'label': 'en',
      'language': 'en',
      'url': 'https://example.com/en.m3u8',
      'mimeType': 'application/x-mpegURL',
      'headers': {'Authorization': 'token'},
    });
    expect(audio, equals(audio));
    expect(audio, isNot(equals(subtitle)));
    expect(audio.hashCode, isA<int>());
    expect(audio.toString(), 'M3u8AudioTrack(en, en)');

    expect(subtitle.label, 'zh');
    expect(subtitle.toMap(), {
      'id': 'zh',
      'label': 'zh',
      'language': 'zh',
      'url': 'https://example.com/zh.vtt',
      'mimeType': 'text/vtt',
      'headers': {'Cookie': 'a=b'},
    });
    expect(subtitle, equals(subtitle));
    expect(subtitle.hashCode, isA<int>());
    expect(subtitle.toString(), 'M3u8SubtitleTrack(zh, zh)');
    expect(
      M3u8SubtitleTrack.fromMap(const <Object?, Object?>{}).headers,
      isEmpty,
    );
  });

  test('cache info validates payload and clamps usage ratio', () {
    expect(
      M3u8CacheInfo.fromMap(const <Object?, Object?>{
        'maxSizeBytes': 100.8,
        'sizeBytes': 150,
      }).usageRatio,
      1,
    );
    expect(
      () => M3u8CacheInfo.fromMap(const <Object?, Object?>{
        'maxSizeBytes': 0,
        'sizeBytes': 1,
      }),
      throwsArgumentError,
    );
    expect(
      () => M3u8CacheInfo.fromMap(const <Object?, Object?>{
        'maxSizeBytes': 100,
        'sizeBytes': -1,
      }),
      throwsArgumentError,
    );
    expect(
      () => M3u8CacheInfo.fromMap(const <Object?, Object?>{
        'maxSizeBytes': '100',
        'sizeBytes': 1,
      }),
      throwsArgumentError,
    );
    expect(
      const M3u8CacheInfo(maxSizeBytes: 100, sizeBytes: 40).toString(),
      contains('sizeBytes: 40'),
    );
  });

  test('cache task parses enum fallbacks copyWith and progress', () {
    final task = M3u8CacheTask.fromMap(const <Object?, Object?>{
      'taskId': 'task-1',
      'url': 'https://example.com/index.m3u8',
      'owner': 'player',
      'status': 'paused',
      'sourceType': 'progressive',
      'priority': 3.8,
      'bytesCached': 3,
      'bytesTotal': 2,
      'downloadSpeedBytesPerSecond': 512,
      'cacheHitCount': 1,
      'networkFetchCount': 2,
      'segmentIndex': 5,
      'segmentCount': 8,
      'currentUrl': 'https://example.com/seg.ts',
      'retryCount': 1,
      'updatedAt': 1700000000000,
      'metadata': {'title': 'Episode 1'},
      'event': 'error',
      'error': {'code': 'cache_error', 'message': 'failed'},
    });

    expect(task.owner, M3u8CacheTaskOwner.player);
    expect(task.owner.platformValue, 'player');
    expect(task.status, M3u8CacheTaskStatus.paused);
    expect(task.status.platformValue, 'paused');
    expect(task.sourceType, M3u8SourceType.progressive);
    expect(task.progress, 1);
    expect(task.updatedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(task.event?.type, M3u8CacheEventType.error);
    expect(task.metadata, {'title': 'Episode 1'});

    final copied = task.copyWith(
      status: M3u8CacheTaskStatus.completed,
      currentUrl: null,
      updatedAt: null,
      event: null,
      metadata: const {'done': true},
    );
    expect(copied.status.platformValue, 'completed');
    expect(copied.currentUrl, isNull);
    expect(copied.updatedAt, isNull);
    expect(copied.event, isNull);
    expect(copied.metadata, {'done': true});

    expect(const M3u8CacheTask(taskId: 'empty', url: 'u').progress, 0);
    expect(M3u8CacheTaskOwner.from('other'), M3u8CacheTaskOwner.standalone);
    expect(M3u8CacheTaskOwner.standalone.platformValue, 'standalone');
    expect(M3u8CacheTaskStatus.from('running').platformValue, 'running');
    expect(M3u8CacheTaskStatus.from('cancelled').platformValue, 'cancelled');
    expect(M3u8CacheTaskStatus.from('error').platformValue, 'error');
    expect(M3u8CacheTaskStatus.from('other'), M3u8CacheTaskStatus.queued);
  });

  test('cache event parses status fallbacks metadata and progress', () {
    final playerEvent = M3u8CacheEvent.fromMap(const <Object?, Object?>{
      'event': 'progress',
      'url': 'https://example.com/index.m3u8',
      'bytesCached': 1,
      'bytesTotal': 4,
      'metadata': {'1': 'one'},
      'duration': -1,
      'position': -1,
    });
    expect(playerEvent.owner, M3u8CacheEventOwner.player);
    expect(playerEvent.status, M3u8CacheEventStatus.running);
    expect(playerEvent.byteProgress, 0.25);
    expect(playerEvent.duration, isNull);
    expect(playerEvent.position, isNull);
    expect(playerEvent.metadata, {'1': 'one'});

    expect(
      M3u8CacheEvent.fromMap(const <Object?, Object?>{
        'event': 'cancelled',
      }).status,
      M3u8CacheEventStatus.cancelled,
    );
    expect(
      M3u8CacheEvent.fromMap(const <Object?, Object?>{
        'event': 'completed',
      }).status,
      M3u8CacheEventStatus.completed,
    );
    expect(
      M3u8CacheEvent.fromMap(const <Object?, Object?>{'event': 'error'}).status,
      M3u8CacheEventStatus.error,
    );
    expect(
      M3u8CacheEvent.fromMap(const <Object?, Object?>{
        'event': 'progress',
        'bytesTotal': 0,
      }).byteProgress,
      0,
    );
  });

  test('recovery policy maps copies equality and debug validation', () {
    const policy = M3u8RecoveryPolicy(
      rebufferThreshold: 2,
      minimumRecoveryInterval: Duration(seconds: 5),
      minimumAutoQualityHeight: 480,
    );
    final copied = policy.copyWith(isEnabled: false);

    expect(copied.isEnabled, false);
    expect(copied.rebufferThreshold, 2);
    expect(policy.toMap(), {
      'isEnabled': true,
      'rebufferThreshold': 2,
      'minimumRecoveryIntervalMs': 5000,
      'minimumAutoQualityHeight': 480,
    });
    expect(policy, equals(policy));
    expect(policy, isNot(equals(copied)));
    expect(policy.hashCode, isA<int>());
    expect(policy.toString(), contains('minimumAutoQualityHeight: 480'));
    expect(() => policy.debugAssertValid(), returnsNormally);
  });

  test('player value quality and error expose stable derived values', () {
    const qualityByHeight = M3u8Quality(id: '720p', label: '720p', height: 720);
    final qualityByBitrate = M3u8Quality.fromMap(const <Object?, Object?>{
      'bitrate': 1500000,
    });
    final unknownQuality = M3u8Quality.fromMap(const <Object?, Object?>{});
    final value = M3u8PlayerValue(
      bufferedPosition: const Duration(seconds: 10),
      diskCacheStartPosition: const Duration(seconds: 30),
      diskCachePosition: const Duration(seconds: 40),
      selectedQuality: qualityByHeight,
      selectedSubtitle: const M3u8SubtitleTrack(id: 'en', label: 'English'),
      selectedAudioTrack: const M3u8AudioTrack(id: 'main', label: 'Main'),
      diagnostics: const {'sessionId': 'session-1'},
      size: const Size(1920, 1080),
      error: const M3u8PlayerError(code: 'source', message: 'failed'),
    );

    expect(value.hasError, true);
    expect(value.diagnostics, {'sessionId': 'session-1'});
    expect(value.visibleBufferedPosition, const Duration(seconds: 40));
    expect(value.visibleBufferedStartPosition, const Duration(seconds: 30));
    expect(value.aspectRatio, 1920 / 1080);
    expect(value.toString(), contains('M3u8PlayerError(source, failed)'));
    expect(value.toString(), contains('diagnostics'));
    expect(
      value.copyWith(
        selectedSubtitle: null,
        selectedAudioTrack: null,
        diagnostics: const {'sessionId': 'session-2'},
        error: null,
      )..toString(),
      isA<M3u8PlayerValue>()
          .having((item) => item.selectedSubtitle, 'selectedSubtitle', isNull)
          .having(
            (item) => item.selectedAudioTrack,
            'selectedAudioTrack',
            isNull,
          )
          .having(
            (item) => item.diagnostics['sessionId'],
            'diagnostics.sessionId',
            'session-2',
          )
          .having((item) => item.error, 'error', isNull),
    );

    expect(
      const M3u8PlayerValue(
        bufferedPosition: Duration(seconds: 5),
        size: Size.zero,
      ).visibleBufferedStartPosition,
      Duration.zero,
    );
    expect(const M3u8PlayerValue().aspectRatio, 16 / 9);
    expect(
      M3u8Quality.fromMap(const <Object?, Object?>{'isAuto': true}),
      M3u8Quality.auto,
    );
    expect(qualityByBitrate.id, '1500000bps');
    expect(qualityByBitrate.label, '1500 Kbps');
    expect(unknownQuality.id, 'unknown');
    expect(unknownQuality.label, 'Unknown');
    expect(qualityByHeight.toMap(), containsPair('height', 720));
    expect(qualityByHeight, equals(qualityByHeight));
    expect(qualityByHeight, isNot(equals(qualityByBitrate)));
    expect(qualityByHeight.hashCode, isA<int>());
    expect(qualityByHeight.toString(), 'M3u8Quality(720p, 720p)');
    expect(
      const M3u8PlayerError(code: 'x', message: 'y').toString(),
      'M3u8PlayerError(x, y)',
    );
  });

  test('platform interface default methods throw and exceptions map', () {
    final platform = _BarePlatform();
    const source = M3u8Source(videoUrl: 'https://example.com/index.m3u8');

    expect(() => platform.events, throwsUnimplementedError);
    expect(() => platform.cacheEvents, throwsUnimplementedError);
    expect(() => platform.create(source: source), throwsUnimplementedError);
    expect(() => platform.play(1), throwsUnimplementedError);
    expect(() => platform.pause(1), throwsUnimplementedError);
    expect(() => platform.seekTo(1, Duration.zero), throwsUnimplementedError);
    expect(
      () => platform.setQuality(1, M3u8Quality.auto),
      throwsUnimplementedError,
    );
    expect(
      () => platform.setRecoveryPolicy(1, M3u8RecoveryPolicy.defaults),
      throwsUnimplementedError,
    );
    expect(() => platform.setPlaybackSpeed(1, 1), throwsUnimplementedError);
    expect(() => platform.setVolume(1, 1), throwsUnimplementedError);
    expect(() => platform.setMuted(1, true), throwsUnimplementedError);
    expect(() => platform.setSubtitle(1, null), throwsUnimplementedError);
    expect(() => platform.setAudioTrack(1, null), throwsUnimplementedError);
    expect(() => platform.disposePlayer(1), throwsUnimplementedError);
    expect(
      () => platform.configureCache(maxSizeBytes: 1024),
      throwsUnimplementedError,
    );
    expect(() => platform.clearCache(), throwsUnimplementedError);
    expect(() => platform.getCacheInfo(), throwsUnimplementedError);
    expect(() => platform.precache(source: source), throwsUnimplementedError);
    expect(() => platform.cancelPrecache('task'), throwsUnimplementedError);
    expect(() => platform.pausePrecache('task'), throwsUnimplementedError);
    expect(() => platform.resumePrecache('task'), throwsUnimplementedError);
    expect(() => platform.cacheTasks(), throwsUnimplementedError);
    expect(() => platform.sourceCacheInfo(source), throwsUnimplementedError);
    expect(() => platform.clearSourceCache(source), throwsUnimplementedError);

    final exception = PlayerM3u8PlatformException.fromPlatformException(
      PlatformException(code: 'code', details: const {'a': 1}),
    );
    expect(exception.code, 'code');
    expect(exception.message, 'code');
    expect(exception.details, {'a': 1});
    expect(exception.toString(), 'PlayerM3u8PlatformException(code, code)');
  });

  testWidgets('player widget renders background and subtitle overlay', (
    tester,
  ) async {
    final platform = FakePlayerM3u8Platform();
    final controller = M3u8PlayerController(platform: platform);
    addTearDown(controller.dispose);
    addTearDown(platform.eventController.close);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: M3u8Player(
            controller: controller,
            backgroundColor: const Color(0xFF123456),
          ),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF123456),
      ),
      findsOneWidget,
    );
    expect(find.byType(Texture), findsNothing);

    await controller.initialize(
      source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
    );
    platform.eventController.add(
      const M3u8PlayerEvent(
        playerId: 7,
        type: M3u8PlayerEventType.initialized,
        size: Size(640, 360),
        subtitleText: 'Caption',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Texture), findsOneWidget);
    expect(find.text('Caption'), findsOneWidget);
  });
}

class _BarePlatform extends PlayerM3u8Platform {}
