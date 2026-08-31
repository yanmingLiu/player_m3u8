import 'package:flutter/material.dart';

import '../data/drama_models.dart';
import 'drama_cover_image.dart';

class FeedEpisodeSheet extends StatelessWidget {
  const FeedEpisodeSheet({
    super.key,
    required this.series,
    required this.episodes,
    required this.currentIndex,
  });
  final DramaSeries series;
  final List<DramaEpisode> episodes;
  final int currentIndex;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xfff7f7fb),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .45,
        maxChildSize: .92,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            _handle(),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            _header(context),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Episodes',
                      style: TextStyle(
                        color: Color(0xff4f46e5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(child: Center(child: Text('Synopsis'))),
              ],
            ),
            const Divider(height: 1),
            _grid(context),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                series.description,
                style: const TextStyle(color: Colors.black87, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _handle() =>
      Center(child: Container(width: 40, height: 4, color: Colors.black12));
  Widget _header(BuildContext context) {
    final e = episodes.first;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 76,
            height: 104,
            child: DramaCoverImage(
              url: e.cover,
              fit: BoxFit.cover,
              semanticLabel: series.title,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                series.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Likes 12.5k'),
              const SizedBox(height: 4),
              const Text('@NeoExplorer'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: episodes.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
    ),
    itemBuilder: (_, i) => InkWell(
      onTap: () => Navigator.pop(context, i),
      child: Container(
        decoration: BoxDecoration(
          color: i == currentIndex ? const Color(0xff8175f5) : Colors.white,
          shape: BoxShape.circle,
        ),
        child: Center(child: Text('${episodes[i].number}')),
      ),
    ),
  );
}
