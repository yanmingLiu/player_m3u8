import 'package:flutter/material.dart';

import '../data/drama_models.dart';
import '../data/drama_repository.dart';
import 'drama_cover_image.dart';
import 'drama_playback_page.dart';

/// Displays locally bundled drama metadata and opens the shared playback page.
class DramaFeedPage extends StatefulWidget {
  const DramaFeedPage({super.key, this.repository = const DramaRepository()});

  final DramaRepository repository;

  @override
  State<DramaFeedPage> createState() => _DramaFeedPageState();
}

class _DramaFeedPageState extends State<DramaFeedPage> {
  late Future<List<DramaSeries>> _seriesFuture;

  @override
  void initState() {
    super.initState();
    _seriesFuture = widget.repository.load();
  }

  @override
  void didUpdateWidget(covariant DramaFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    setState(() {
      _seriesFuture = widget.repository.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drama Feed')),
      body: FutureBuilder<List<DramaSeries>>(
        future: _seriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('加载失败，重试'),
              ),
            );
          }
          final series = snapshot.data ?? const <DramaSeries>[];
          if (series.isEmpty) {
            return const Center(child: Text('暂无内容'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: series.length,
            itemBuilder: (_, index) => _DramaCard(series: series[index]),
          );
        },
      ),
    );
  }
}

class _DramaCard extends StatelessWidget {
  const _DramaCard({required this.series});
  final DramaSeries series;
  @override
  Widget build(BuildContext context) {
    final first = series.episodes.isEmpty ? null : series.episodes.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: first == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DramaPlaybackPage(
                    episodes: series.episodes,
                    seriesDescription: series.description,
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                height: 150,
                child: first == null
                    ? const ColoredBox(color: Colors.black12)
                    : DramaCoverImage(
                        url: first.cover,
                        fit: BoxFit.cover,
                        semanticLabel: series.title,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('${series.episodes.length} 集'),
                    const SizedBox(height: 6),
                    Text(
                      series.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: series.tags
                          .take(5)
                          .map(
                            (t) => Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
