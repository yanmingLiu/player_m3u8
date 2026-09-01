import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:player_m3u8_example/features/drama/data/drama_models.dart';
import 'package:player_m3u8_example/features/drama/presentation/drama_playback_widgets.dart';
import 'package:player_m3u8_example/features/drama/presentation/feed_episode_sheet.dart';

void main() {
  testWidgets('switches between episode and synopsis tabs', (tester) async {
    final episodes = _episodes(6);
    final series = DramaSeries(
      id: 'series-1',
      title: 'A neon drama',
      description: 'A short synopsis for the selected drama.',
      tags: const [],
      episodes: episodes,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FeedEpisodeSheet(
                    series: series,
                    episodes: episodes,
                    currentIndex: 0,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-240, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('About this Drama'), findsOneWidget);
    expect(find.text(series.description), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(240, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Synopsis'));
    await tester.pumpAndSettle();
    expect(find.text('About this Drama'), findsOneWidget);
    expect(find.text(series.description), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.text('Episodes'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('empty episode lists render a placeholder header', (
    tester,
  ) async {
    const series = DramaSeries(
      id: 'series-empty',
      title: 'Empty drama',
      description: '',
      tags: [],
      episodes: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeedEpisodeSheet(series: series, episodes: [], currentIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Empty drama'), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('selecting a locked tile returns its episode index', (
    tester,
  ) async {
    final episodes = _episodes(6);
    const series = DramaSeries(
      id: 'series-1',
      title: 'Drama',
      description: 'Description',
      tags: [],
      episodes: [],
    );
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FeedEpisodeSheet(
                    series: series,
                    episodes: episodes,
                    currentIndex: 0,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(selected, 2);
  });

  testWidgets('playback item passes the series description to the sheet', (
    tester,
  ) async {
    const episode = DramaEpisode(
      number: 1,
      video: 'https://example.com/episode.mp4',
      cover: '',
      duration: 60,
      seriesTitle: 'Drama',
      seriesId: 'series-1',
    );
    final controller = M3u8PlayerController();
    controller.value = const M3u8PlayerValue(
      isInitialized: true,
      duration: Duration(minutes: 1),
    );
    final uiState = DramaPlaybackUiState();
    addTearDown(() {
      uiState.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 375,
          height: 812,
          child: DramaPlaybackItem(
            episode: episode,
            episodes: const [episode],
            seriesDescription: 'Synopsis loaded from the series item.',
            currentIndex: 0,
            controller: controller,
            isActive: false,
            uiState: uiState,
            onBack: () {},
            onSurfaceTap: () {},
            onPlayPause: () {},
            onEpisodeSelected: (_) {},
            onSpeedSelected: (_) {},
            onScrubbingChanged: (_) {},
            onScrubPositionChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drama · Ep. 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synopsis'));
    await tester.pumpAndSettle();

    expect(find.text('Synopsis loaded from the series item.'), findsOneWidget);
  });
}

List<DramaEpisode> _episodes(int count) {
  return [
    for (var i = 0; i < count; i++)
      DramaEpisode(
        number: i + 1,
        video: 'https://example.com/${i + 1}.mp4',
        cover: '',
        duration: 60,
        seriesTitle: 'Drama',
        seriesId: 'series-1',
      ),
  ];
}
