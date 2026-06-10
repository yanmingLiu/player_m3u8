import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8_example/main.dart';

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
    expect(find.text('预取空闲'), findsOneWidget);

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
    expect(find.textContaining('磁盘缓存:'), findsOneWidget);
    expect(find.textContaining('启动耗时:'), findsOneWidget);
    expect(find.textContaining('卡顿次数:'), findsOneWidget);
    expect(find.textContaining('卡顿时长:'), findsOneWidget);
    expect(find.textContaining('播放速度:'), findsOneWidget);
    expect(find.textContaining('音量:'), findsOneWidget);
    expect(find.textContaining('清晰度切换:'), findsOneWidget);
    expect(find.textContaining('恢复次数:'), findsOneWidget);
    expect(find.textContaining('视频码率:'), findsOneWidget);

    await _scrollTo(tester, find.text('QoE 快照'));

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

    expect(find.text('Precache idle'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.play_arrow));

    expect(find.text('Auto'), findsOneWidget);

    await _scrollTo(tester, find.textContaining('Position:'));

    expect(find.textContaining('Position:'), findsOneWidget);

    await _scrollTo(tester, find.text('QoE snapshots'));

    expect(find.text('QoE snapshots'), findsOneWidget);
    expect(find.text('QoE waiting for first sample'), findsOneWidget);
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
