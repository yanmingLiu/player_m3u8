import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8_example/main.dart';

void main() {
  testWidgets('shows player example chrome', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlayerExamplePage(autoInitialize: false)),
    );

    expect(find.text('M3U8 Player'), findsWidgets);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('Nifty VOD'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.download));

    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.text('Precache idle'), findsOneWidget);

    await _scrollTo(tester, find.byIcon(Icons.play_arrow));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsOneWidget);
    expect(find.byIcon(Icons.forward_10), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    await _scrollTo(tester, find.textContaining('Position:'));

    expect(find.textContaining('Position:'), findsOneWidget);
    expect(find.textContaining('Player buffer:'), findsOneWidget);
    expect(find.textContaining('Disk cache:'), findsOneWidget);
    expect(find.textContaining('Startup:'), findsOneWidget);
    expect(find.textContaining('Rebuffers:'), findsOneWidget);
    expect(find.textContaining('Rebuffer time:'), findsOneWidget);
    expect(find.textContaining('Playback speed:'), findsOneWidget);
    expect(find.textContaining('Volume:'), findsOneWidget);
    expect(find.textContaining('Quality switches:'), findsOneWidget);
    expect(find.textContaining('Recovery:'), findsOneWidget);
    expect(find.textContaining('Video bitrate:'), findsOneWidget);

    await _scrollTo(tester, find.text('QoE snapshots'));

    expect(find.text('QoE snapshots'), findsOneWidget);
    expect(find.text('QoE waiting for first sample'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
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
