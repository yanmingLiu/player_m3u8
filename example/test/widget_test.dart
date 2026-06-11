import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8_example/main.dart';
import 'package:player_m3u8_example/src/example_strings.dart';
import 'package:player_m3u8_example/src/video_scaffold.dart';

void main() {
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
    expect(find.text('Apple BipBop'), findsOneWidget);

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
    expect(find.text('Apple BipBop'), findsOneWidget);

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
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}
