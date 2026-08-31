import 'package:flutter/material.dart';

import '../features/drama/presentation/drama_feed_page.dart';
import '../features/player/presentation/player_example_page.dart';

/// Entry page for the example features.
///
/// Each feature is pushed as its own route so a player can enter landscape
/// fullscreen without inheriting navigation chrome from this page.
class DemoShell extends StatelessWidget {
  const DemoShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功能列表')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FeatureTile(
            icon: Icons.ondemand_video_outlined,
            title: 'M3U8 播放器',
            subtitle: '播放、字幕、清晰度、缓存和 QoE 诊断',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlayerExamplePage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.dynamic_feed_outlined,
            title: 'Drama Feed',
            subtitle: '短剧列表、选集播放和下一集预加载',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DramaFeedPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
