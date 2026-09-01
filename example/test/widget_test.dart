import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8/player_m3u8_platform_interface.dart';
import 'package:player_m3u8/src/m3u8_player_event.dart';
import 'package:player_m3u8_example/main.dart';
import 'package:player_m3u8_example/features/drama/data/drama_models.dart';
import 'package:player_m3u8_example/features/drama/presentation/drama_playback_page.dart';
import 'package:player_m3u8_example/features/drama/presentation/drama_playback_widgets.dart';
import 'package:player_m3u8_example/features/player/presentation/player_panels.dart';
import 'package:player_m3u8_example/features/player/presentation/player_video_scaffold.dart';
import 'package:player_m3u8_example/shared/localization/example_strings.dart';
import 'package:player_m3u8_example/shared/widgets/buffered_seek_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home opens features as independent routes', (
    WidgetTester tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(home: const DemoShell(), navigatorObservers: [observer]),
    );

    expect(find.text('功能列表'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('M3U8 播放器'), findsOneWidget);
    expect(find.text('Drama Feed'), findsOneWidget);
    expect(observer.pushCount, 1);

    await tester.tap(find.byType(ListTile).at(1));
    await tester.pump(const Duration(milliseconds: 400));

    expect(observer.pushCount, 2);
    expect(find.text('Drama Feed', skipOffstage: true), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(observer.popCount, 1);
    expect(find.text('功能列表'), findsOneWidget);
  });

  testWidgets('shows player example chrome in Chinese by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlayerExamplePage(autoInitialize: false)),
    );

    expect(find.text('M3U8 播放器'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('Mux Big Buck Bunny'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.download));

    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.text('下载空闲'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.play_arrow));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsOneWidget);
    expect(find.byIcon(Icons.forward_10), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);

    await _scrollTo(tester, find.textContaining('位置:'));

    expect(find.textContaining('位置:'), findsOneWidget);
    expect(find.textContaining('播放器缓冲:'), findsOneWidget);
    expect(find.textContaining('磁盘缓存:'), findsWidgets);
    expect(find.textContaining('启动耗时:'), findsOneWidget);
    expect(find.textContaining('卡顿次数:'), findsOneWidget);
    expect(find.textContaining('卡顿时长:'), findsOneWidget);
    expect(find.textContaining('播放速度:'), findsOneWidget);
    expect(find.textContaining('音量:'), findsOneWidget);
    expect(find.textContaining('清晰度切换:'), findsOneWidget);
    expect(find.textContaining('恢复次数:'), findsOneWidget);
    expect(find.textContaining('视频码率:'), findsOneWidget);

    await _scrollTo(tester, find.text('QoE 快照'));

    final cacheMetricsTopLeft = tester.getTopLeft(find.text('缓存/下载指标'));
    final qoeTopLeft = tester.getTopLeft(find.text('QoE 快照'));
    expect(cacheMetricsTopLeft.dy, lessThan(qoeTopLeft.dy));
    expect(find.textContaining('缓存占用:'), findsOneWidget);
    expect(find.text('QoE 快照'), findsOneWidget);
    expect(find.text('等待首个 QoE 采样'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('switches player example chrome to English', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlayerExamplePage(autoInitialize: false)),
    );

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('M3U8 Player'), findsWidgets);
    expect(find.text('中文'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('Mux Big Buck Bunny'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.download));

    expect(find.text('Download idle'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.play_arrow));

    expect(find.text('Auto'), findsOneWidget);

    await _scrollTo(tester, find.textContaining('Position:'));

    expect(find.textContaining('Position:'), findsOneWidget);

    await _scrollTo(tester, find.text('QoE snapshots'));

    final cacheMetricsTopLeft = tester.getTopLeft(
      find.text('Cache/download metrics'),
    );
    final qoeTopLeft = tester.getTopLeft(find.text('QoE snapshots'));
    expect(cacheMetricsTopLeft.dy, lessThan(qoeTopLeft.dy));
    expect(find.textContaining('Cache size:'), findsOneWidget);
    expect(find.text('QoE snapshots'), findsOneWidget);
    expect(find.text('QoE waiting for first sample'), findsOneWidget);
  });

  testWidgets('landscape controls can be locked and unlocked', (
    WidgetTester tester,
  ) async {
    final controller = M3u8PlayerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildLandscapeScaffold(
        controller: controller,
        value: const M3u8PlayerValue(
          isInitialized: true,
          duration: Duration(minutes: 10),
          position: Duration(seconds: 10),
        ),
      ),
    );

    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.text('Mux Big Buck Bunny'), findsOneWidget);
    expect(find.text('字幕'), findsOneWidget);
    expect(find.text('选集'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pump();

    expect(find.byIcon(Icons.lock_open), findsNothing);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    expect(find.text('Mux Big Buck Bunny'), findsNothing);
    expect(find.text('字幕'), findsNothing);
    expect(find.text('选集'), findsNothing);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();

    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.text('Mux Big Buck Bunny'), findsOneWidget);
    expect(find.text('字幕'), findsOneWidget);
    expect(find.text('选集'), findsOneWidget);
  });

  testWidgets('scrolling landscape side panels does not change volume', (
    WidgetTester tester,
  ) async {
    final platform = _DramaPlaybackTestPlatform();
    final controller = M3u8PlayerController(platform: platform);
    addTearDown(controller.dispose);
    await controller.initialize(
      source: const M3u8Source(
        videoUrl: 'https://example.com/video.m3u8',
        sourceType: M3u8SourceType.hls,
      ),
    );
    controller.value = const M3u8PlayerValue(
      isInitialized: true,
      duration: Duration(minutes: 10),
      position: Duration(seconds: 10),
      availableQualities: [
        M3u8Quality(id: 'q1', label: '360p'),
        M3u8Quality(id: 'q2', label: '480p'),
        M3u8Quality(id: 'q3', label: '720p'),
        M3u8Quality(id: 'q4', label: '1080p'),
        M3u8Quality(id: 'q5', label: '1440p'),
        M3u8Quality(id: 'q6', label: '2160p'),
      ],
    );

    await tester.pumpWidget(
      _buildLandscapeScaffold(
        controller: controller,
        value: controller.value,
        episodes: [for (var i = 0; i < 20; i++) 'Episode ${i + 1}'],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('选集').first);
    await tester.pump();

    final gestureControls = tester.widget<M3u8PlayerGestureControls>(
      find.byType(M3u8PlayerGestureControls),
    );
    expect(gestureControls.config.enabled, isFalse);

    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pump();

    expect(platform.volumeValues, isEmpty);

    await tester.tapAt(const Offset(12, 200));
    await tester.pump();
    expect(find.byType(ListView), findsNothing);
    expect(
      tester
          .widget<M3u8PlayerGestureControls>(
            find.byType(M3u8PlayerGestureControls),
          )
          .config
          .enabled,
      isTrue,
    );

    await tester.tap(find.text('自动').first);
    await tester.pump();
    expect(
      tester
          .widget<M3u8PlayerGestureControls>(
            find.byType(M3u8PlayerGestureControls),
          )
          .config
          .enabled,
      isFalse,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pump();

    expect(platform.volumeValues, isEmpty);
  });

  testWidgets('device rotation enters and exits fullscreen unless locked', (
    WidgetTester tester,
  ) async {
    final orientationCalls = <List<DeviceOrientation>>[];
    final uiModeCalls = <SystemUiMode>[];

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerExamplePage(
          autoInitialize: false,
          orientationSetter: (orientations) async {
            orientationCalls.add(List<DeviceOrientation>.of(orientations));
          },
          systemUiModeSetter: (mode) async {
            uiModeCalls.add(mode);
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsNothing);

    await _rotateTestView(tester, const Size(844, 390));

    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(uiModeCalls, contains(SystemUiMode.immersiveSticky));
    expect(orientationCalls.last, isEmpty);

    await _rotateTestView(tester, const Size(390, 844));

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsNothing);
    expect(uiModeCalls, contains(SystemUiMode.edgeToEdge));
    expect(orientationCalls.last, isEmpty);

    await _rotateTestView(tester, const Size(844, 390));
    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pump();

    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(orientationCalls.last, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await _rotateTestView(tester, const Size(390, 844));

    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
  });

  testWidgets('hiding an uninitialized player does not call native pause', (
    WidgetTester tester,
  ) async {
    final previousPlatform = PlayerM3u8Platform.instance;
    final platform = _DramaPlaybackTestPlatform();
    PlayerM3u8Platform.instance = platform;
    addTearDown(() {
      PlayerM3u8Platform.instance = previousPlatform;
      unawaited(platform.eventsController.close());
    });

    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: PlayerExamplePage(
                    autoInitialize: false,
                    visible: visible,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: TextButton(
                    onPressed: () => setState(() => visible = false),
                    child: const Text('hide'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('hide'));
    await tester.pump();

    expect(platform.pauseCalls, 0);
  });

  testWidgets('manual fullscreen requests landscape orientation', (
    WidgetTester tester,
  ) async {
    final orientationCalls = <List<DeviceOrientation>>[];
    final uiModeCalls = <SystemUiMode>[];
    final physicalOrientationController =
        StreamController<PhysicalDeviceOrientation>();
    addTearDown(physicalOrientationController.close);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerExamplePage(
          autoInitialize: false,
          orientationSetter: (orientations) async {
            orientationCalls.add(List<DeviceOrientation>.of(orientations));
          },
          systemUiModeSetter: (mode) async {
            uiModeCalls.add(mode);
          },
          physicalOrientationStreamFactory: () =>
              physicalOrientationController.stream,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(orientationCalls.single, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    expect(uiModeCalls, contains(SystemUiMode.immersiveSticky));

    await tester.pump(const Duration(milliseconds: 350));
    expect(orientationCalls, hasLength(1));
    expect(orientationCalls.last, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await _rotateTestView(tester, const Size(390, 844));
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(uiModeCalls, isNot(contains(SystemUiMode.edgeToEdge)));

    await tester.pump(const Duration(milliseconds: 850));
    await _rotateTestView(tester, const Size(390, 844));
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(orientationCalls, hasLength(1));

    await _rotateTestView(tester, const Size(844, 390));
    expect(orientationCalls, hasLength(2));
    expect(orientationCalls.last, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await _rotateTestView(tester, const Size(390, 844));

    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(uiModeCalls, isNot(contains(SystemUiMode.edgeToEdge)));
    expect(orientationCalls.last, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    physicalOrientationController.add(PhysicalDeviceOrientation.landscape);
    await tester.pump();

    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(orientationCalls, hasLength(2));
    expect(orientationCalls.last, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    physicalOrientationController.add(PhysicalDeviceOrientation.portrait);
    await tester.pump();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsNothing);
    expect(uiModeCalls, contains(SystemUiMode.edgeToEdge));
    expect(orientationCalls.last, isEmpty);
  });

  testWidgets('more sheet opens download list', (WidgetTester tester) async {
    var downloadsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  PortraitMoreSheet.show(
                    context: context,
                    value: const M3u8PlayerValue(),
                    isPrecacheRunning: false,
                    precacheSupported: true,
                    autoPlayNext: true,
                    loopMode: ExampleLoopMode.none,
                    onPrecache: () {},
                    onShowDownloads: () {
                      downloadsOpened = true;
                      Navigator.of(context).pop();
                      Future<void>.microtask(
                        () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('暂无下载任务'),
                          ),
                        ),
                      );
                    },
                    onSpeedSelected: (_) {},
                    onAutoPlayNextChanged: (_) {},
                    onLoopModeChanged: (_) {},
                    strings: const ExampleStrings(ExampleLanguage.zh),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('下载列表'), findsOneWidget);
    expect(find.text('不感兴趣'), findsNothing);

    await tester.tap(find.byIcon(Icons.download_done_outlined));
    await tester.pumpAndSettle();

    expect(downloadsOpened, true);
    expect(find.text('暂无下载任务'), findsOneWidget);
  });

  testWidgets('download sheet disables controls for finished downloads', (
    WidgetTester tester,
  ) async {
    final tasks = ValueNotifier<List<M3u8CacheTask>>([
      M3u8CacheTask.fromMap({
        'taskId': 'standalone-finished',
        'url': 'https://example.com/finished.m3u8',
        'owner': 'standalone',
        'status': 'completed',
        'sourceType': 'hls',
        'diskCachePercent': 100.0,
        'metadata': {
          'title': 'Finished Episode',
          'source': {
            'videoUrl': 'https://example.com/finished.m3u8',
            'sourceType': 'hls',
          },
          'quality': {'id': '720p', 'label': '720p', 'height': 720},
        },
      }),
    ]);
    addTearDown(tasks.dispose);
    M3u8CacheTask? playedTask;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadListSheet(
            strings: const ExampleStrings(ExampleLanguage.zh),
            tasksListenable: tasks,
            onPlay: (task) {
              playedTask = task;
            },
            onPause: (_) {},
            onResume: (_) {},
            onCancel: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Finished Episode'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.text('Finished Episode'));
    expect(playedTask?.taskId, 'standalone-finished');
  });

  testWidgets('download sheet updates when task notifier changes', (
    WidgetTester tester,
  ) async {
    final tasks = ValueNotifier<List<M3u8CacheTask>>([
      M3u8CacheTask.fromMap({
        'taskId': 'download-1',
        'url': 'https://example.com/video.m3u8',
        'owner': 'standalone',
        'status': 'running',
        'sourceType': 'hls',
        'bytesCached': 27,
        'bytesTotal': 181,
      }),
    ]);
    addTearDown(tasks.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadListSheet(
            strings: const ExampleStrings(ExampleLanguage.zh),
            tasksListenable: tasks,
            onPlay: (_) {},
            onPause: (_) {},
            onResume: (_) {},
            onCancel: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('running'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    tasks.value = [
      tasks.value.single.copyWith(status: M3u8CacheTaskStatus.paused),
    ];
    await tester.pump();

    expect(find.textContaining('paused'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('hides drama chrome while scrubbing the progress bar', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousPlatform = PlayerM3u8Platform.instance;
    final platform = _DramaPlaybackTestPlatform();
    PlayerM3u8Platform.instance = platform;
    addTearDown(() {
      PlayerM3u8Platform.instance = previousPlatform;
      unawaited(platform.eventsController.close());
    });

    const episode = DramaEpisode(
      number: 1,
      video: 'https://example.com/episode.mp4',
      cover: '',
      duration: 100,
      seriesTitle: '测试剧集',
      seriesId: 'test-series',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: DramaPlaybackPage(episodes: <DramaEpisode>[episode]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.initialized,
        duration: const Duration(minutes: 5),
        bufferedPosition: const Duration(minutes: 2),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('测试剧集'), findsOneWidget);
    expect(find.text('Drama · Ep. 1'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BufferedSeekBar)),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(find.textContaining(' / 05:00'), findsOneWidget);
    expect(find.text('00:00 / 05:00'), findsNothing);
    expect(find.text('测试剧集'), findsNothing);
    expect(find.text('Drama · Ep. 1'), findsNothing);

    await gesture.up();
    await tester.pump();
    expect(find.text('测试剧集'), findsOneWidget);
    expect(find.text('Drama · Ep. 1'), findsOneWidget);
    expect(platform.seekPositions, isNotEmpty);
  });

  testWidgets('full-screen playback gesture toggles the initialized player', (
    WidgetTester tester,
  ) async {
    final todoLogs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        todoLogs.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousPlatform = PlayerM3u8Platform.instance;
    final platform = _DramaPlaybackTestPlatform();
    PlayerM3u8Platform.instance = platform;
    addTearDown(() {
      PlayerM3u8Platform.instance = previousPlatform;
      unawaited(platform.eventsController.close());
    });

    const episode = DramaEpisode(
      number: 1,
      video: 'https://example.com/episode.mp4',
      cover: '',
      duration: 100,
      seriesTitle: '测试剧集',
      seriesId: 'test-series',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: DramaPlaybackPage(episodes: <DramaEpisode>[episode]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.initialized,
        duration: const Duration(minutes: 5),
      ),
    );
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.playing,
        duration: const Duration(minutes: 5),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(M3u8PlayerGestureControls), findsNothing);
    platform.pauseCalls = 0;
    final playbackItem = tester.widget<DramaPlaybackItem>(
      find.byType(DramaPlaybackItem),
    );
    playbackItem.uiState.speedMenuVisible.value = true;
    await tester.pump();
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();

    expect(playbackItem.uiState.speedMenuVisible.value, isFalse);
    expect(platform.pauseCalls, 0);

    await tester.pump(const Duration(seconds: 3));

    expect(playbackItem.uiState.overlayVisible.value, isFalse);
    expect(find.text('测试剧集'), findsNothing);

    await tester.tapAt(const Offset(200, 200));
    await tester.pump();

    expect(playbackItem.uiState.overlayVisible.value, isTrue);
    expect(find.text('测试剧集'), findsOneWidget);
    expect(platform.pauseCalls, 0);

    await tester.tapAt(const Offset(200, 200));
    await tester.pump();

    expect(platform.pauseCalls, 1);
    expect(todoLogs, contains('[TODO]: drama_pause'));

    final pauseButton = tester.widget<DramaPauseButton>(
      find.byType(DramaPauseButton),
    );
    pauseButton.controller.value = pauseButton.controller.value.copyWith(
      isPlaying: false,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(playbackItem.uiState.overlayVisible.value, isTrue);

    platform.playCalls = 0;
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(platform.playCalls, 1);
    debugPrint = previousDebugPrint;
  });

  testWidgets('logs drama_next only for manual episode switches', (
    WidgetTester tester,
  ) async {
    final todoLogs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        todoLogs.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousPlatform = PlayerM3u8Platform.instance;
    final platform = _DramaPlaybackTestPlatform();
    PlayerM3u8Platform.instance = platform;
    addTearDown(() {
      PlayerM3u8Platform.instance = previousPlatform;
      unawaited(platform.eventsController.close());
    });

    const episodes = <DramaEpisode>[
      DramaEpisode(
        number: 1,
        video: 'https://example.com/episode-1.mp4',
        cover: '',
        duration: 100,
        seriesTitle: '测试剧集',
        seriesId: 'test-series',
      ),
      DramaEpisode(
        number: 2,
        video: 'https://example.com/episode-2.mp4',
        cover: '',
        duration: 100,
        seriesTitle: '测试剧集',
        seriesId: 'test-series',
      ),
      DramaEpisode(
        number: 3,
        video: 'https://example.com/episode-3.mp4',
        cover: '',
        duration: 100,
        seriesTitle: '测试剧集',
        seriesId: 'test-series',
      ),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: DramaPlaybackPage(episodes: episodes)),
    );
    await tester.pump();
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      tester
          .widget<DramaPlaybackItem>(find.byType(DramaPlaybackItem).first)
          .currentIndex,
      1,
    );
    expect(
      todoLogs.where((message) => message == '[TODO]: drama_next'),
      hasLength(1),
    );

    todoLogs.clear();
    tester
        .widget<DramaPlaybackItem>(find.byType(DramaPlaybackItem).first)
        .onEpisodeSelected(2);
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<DramaPlaybackItem>(find.byType(DramaPlaybackItem).first)
          .currentIndex,
      2,
    );
    expect(todoLogs, contains('[TODO]: drama_next'));
    debugPrint = previousDebugPrint;
  });

  testWidgets('automatically plays each following drama episode', (
    WidgetTester tester,
  ) async {
    final todoLogs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        todoLogs.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousPlatform = PlayerM3u8Platform.instance;
    final platform = _DramaPlaybackTestPlatform();
    PlayerM3u8Platform.instance = platform;
    addTearDown(() {
      PlayerM3u8Platform.instance = previousPlatform;
      unawaited(platform.eventsController.close());
    });

    const episodes = <DramaEpisode>[
      DramaEpisode(
        number: 1,
        video: 'https://example.com/episode-1.mp4',
        cover: '',
        duration: 100,
        seriesTitle: '测试剧集',
        seriesId: 'test-series',
      ),
      DramaEpisode(
        number: 2,
        video: 'https://example.com/episode-2.mp4',
        cover: '',
        duration: 100,
        seriesTitle: '测试剧集',
        seriesId: 'test-series',
      ),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: DramaPlaybackPage(episodes: episodes)),
    );
    await tester.pump();
    await tester.pump();

    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.initialized,
        duration: const Duration(minutes: 5),
      ),
    );
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.playing,
        duration: const Duration(minutes: 5),
      ),
    );
    await tester.pump();
    await tester.pump();

    final playbackItem = tester.widget<DramaPlaybackItem>(
      find.byType(DramaPlaybackItem),
    );
    final initialPlayCalls = platform.playCalls;
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.completed,
        duration: const Duration(minutes: 5),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<DramaPlaybackItem>(find.byType(DramaPlaybackItem).first)
          .controller
          .value
          .isCompleted,
      isTrue,
    );
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(playbackItem.uiState.overlayVisible.value, isFalse);
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<DramaPlaybackItem>(find.byType(DramaPlaybackItem).first)
          .currentIndex,
      1,
    );
    expect(platform.playCalls, initialPlayCalls + 1);
    expect(
      todoLogs.where((message) => message == '[TODO]: drama_next'),
      hasLength(1),
    );
    debugPrint = previousDebugPrint;

    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.initialized,
        duration: const Duration(minutes: 5),
      ),
    );
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.playing,
        duration: const Duration(minutes: 5),
      ),
    );
    await tester.pump();
    platform.eventsController.add(
      M3u8PlayerEvent(
        playerId: platform.createdPlayerId!,
        type: M3u8PlayerEventType.completed,
        duration: const Duration(minutes: 5),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<DramaPlaybackItem>(find.byType(DramaPlaybackItem).first)
          .currentIndex,
      1,
    );
    expect(platform.playCalls, initialPlayCalls + 1);
    expect(
      todoLogs.where((message) => message == '[TODO]: drama_next'),
      hasLength(1),
    );
  });

  testWidgets('handles an empty drama episode list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DramaPlaybackPage(episodes: <DramaEpisode>[])),
    );

    expect(find.text('暂无剧集'), findsOneWidget);
  });
}

class _DramaPlaybackTestPlatform extends PlayerM3u8Platform {
  final StreamController<M3u8PlayerEvent> eventsController =
      StreamController<M3u8PlayerEvent>.broadcast();
  final List<Duration> seekPositions = <Duration>[];
  final List<double> volumeValues = <double>[];
  int? createdPlayerId;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Stream<M3u8PlayerEvent> get events => eventsController.stream;

  @override
  Stream<M3u8CacheEvent> get cacheEvents =>
      const Stream<M3u8CacheEvent>.empty();

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
    createdPlayerId = 1;
    return createdPlayerId!;
  }

  @override
  Future<void> play(int playerId) async {
    playCalls++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls++;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumeValues.add(volume);
  }

  @override
  Future<void> disposePlayer(int playerId) async {}
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  int popCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

Widget _buildLandscapeScaffold({
  required M3u8PlayerController controller,
  required M3u8PlayerValue value,
  List<String> episodes = const ['Mux Big Buck Bunny', 'Episode 2'],
}) {
  var controlsLocked = false;
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 844,
        height: 390,
        child: StatefulBuilder(
          builder: (context, setState) {
            return ExampleVideoScaffold(
              controller: controller,
              value: value,
              title: 'Mux Big Buck Bunny',
              episodes: episodes,
              currentEpisodeIndex: 0,
              sourceType: M3u8SourceType.hls,
              strings: const ExampleStrings(ExampleLanguage.zh),
              isFullscreen: true,
              controlsLocked: controlsLocked,
              isBusy: false,
              isPrecacheRunning: false,
              precacheSupported: true,
              autoPlayNext: true,
              loopMode: ExampleLoopMode.none,
              onBack: () {},
              onEnterFullscreen: () {},
              onExitFullscreen: () {},
              onControlsLockedChanged: (locked) {
                setState(() {
                  controlsLocked = locked;
                });
              },
              onEpisodeSelected: (_) {},
              onPrecache: () {},
              onShowDownloads: () {},
              onSpeedSelected: (_) {},
              onAutoPlayNextChanged: (_) {},
              onLoopModeChanged: (_) {},
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}

Future<void> _rotateTestView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pump();
  await tester.pump();
}
