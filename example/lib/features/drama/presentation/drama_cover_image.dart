import 'package:flutter/material.dart';

/// Shared cover rendering with an offline/empty URL fallback.
class DramaCoverImage extends StatelessWidget {
  const DramaCoverImage({
    super.key,
    required this.url,
    required this.fit,
    this.semanticLabel,
  });

  final String url;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.movie_outlined)),
      );
    }
    return Image.network(
      url,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
