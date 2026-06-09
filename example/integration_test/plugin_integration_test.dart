import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:player_m3u8_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PlayerM3u8ExampleApp());
    expect(find.text('M3U8 Player'), findsWidgets);
  });
}
