import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8_example/main.dart';

void main() {
  testWidgets('shows player example chrome', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlayerExamplePage(autoInitialize: false)),
    );

    expect(find.text('M3U8 Player'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('Nifty VOD'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(find.textContaining('Position:'), findsOneWidget);
    expect(find.textContaining('Player buffer:'), findsOneWidget);
    expect(find.textContaining('Disk cache:'), findsOneWidget);
  });
}
