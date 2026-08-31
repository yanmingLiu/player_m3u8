import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8_example/features/drama/data/drama_models.dart';
import 'package:player_m3u8_example/features/drama/data/drama_repository.dart';
import 'package:player_m3u8_example/features/drama/presentation/drama_feed_page.dart';

void main() {
  testWidgets('retries a failed drama feed load', (tester) async {
    var attempts = 0;
    final repository = _FakeDramaRepository(() async {
      attempts += 1;
      if (attempts == 1) {
        throw StateError('temporary failure');
      }
      return const [
        DramaSeries(
          id: 'series-1',
          title: '测试剧集',
          description: '简介',
          tags: [],
          episodes: [],
        ),
      ];
    });

    await tester.pumpWidget(
      MaterialApp(home: DramaFeedPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败，重试'), findsOneWidget);
    await tester.tap(find.text('加载失败，重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('测试剧集'), findsOneWidget);
  });
}

class _FakeDramaRepository extends DramaRepository {
  _FakeDramaRepository(this._loader);

  final Future<List<DramaSeries>> Function() _loader;

  @override
  Future<List<DramaSeries>> load() => _loader();
}
