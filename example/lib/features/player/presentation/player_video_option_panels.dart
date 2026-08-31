part of 'player_video_scaffold.dart';

class PlayerOption<T> {
  const PlayerOption({required this.label, required this.value});

  final String label;
  final T value;
}

class PlayerOptionSheet {
  const PlayerOptionSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<PlayerOption<T>> options,
    T? selectedValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xF21A1A1A),
      barrierColor: Colors.black45,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final option in options)
                  ListTile(
                    title: Text(
                      option.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: option.value == selectedValue
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () => Navigator.pop(context, option.value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubtitleSidePanel extends StatelessWidget {
  const _SubtitleSidePanel({
    required this.strings,
    required this.value,
    required this.onSelected,
  });

  final ExampleStrings strings;
  final M3u8PlayerValue value;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    const offValue = '__off__';
    return PlayerSidePanel<String>(
      widthFactor: 0.32,
      selectedValue: value.selectedSubtitle?.id ?? offValue,
      options: [
        PlayerOption<String>(label: strings.subtitlesOffLabel, value: offValue),
        for (final subtitle in value.availableSubtitles)
          PlayerOption<String>(label: subtitle.label, value: subtitle.id),
      ],
      onSelected: (subtitleId) {
        onSelected(subtitleId == offValue ? null : subtitleId);
      },
    );
  }
}

class _SpeedSidePanel extends StatelessWidget {
  const _SpeedSidePanel({required this.value, required this.onSelected});

  final M3u8PlayerValue value;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    const speeds = <double>[2.0, 1.5, 1.25, 1.0, 0.75, 0.5];
    return PlayerSidePanel<double>(
      widthFactor: 0.32,
      selectedValue: nearestSpeed(value.playbackSpeed, speeds),
      options: [
        for (final speed in speeds)
          PlayerOption<double>(label: speedLabel(speed), value: speed),
      ],
      onSelected: onSelected,
    );
  }
}

class _QualitySidePanel extends StatelessWidget {
  const _QualitySidePanel({
    required this.strings,
    required this.value,
    required this.onSelected,
  });

  final ExampleStrings strings;
  final M3u8PlayerValue value;
  final ValueChanged<M3u8Quality> onSelected;

  @override
  Widget build(BuildContext context) {
    final qualities = <M3u8Quality>[
      M3u8Quality.auto,
      ...value.availableQualities,
    ];
    return PlayerSidePanel<String>(
      widthFactor: 0.34,
      selectedValue: value.selectedQuality.id,
      options: [
        for (final quality in qualities)
          PlayerOption<String>(
            label: qualityLabel(quality, strings),
            value: quality.id,
          ),
      ],
      onSelected: (qualityId) {
        final quality = qualities.firstWhere(
          (item) => item.id == qualityId,
          orElse: () => M3u8Quality.auto,
        );
        onSelected(quality);
      },
    );
  }
}

class PlayerSidePanel<T> extends StatelessWidget {
  const PlayerSidePanel({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.widthFactor = 0.34,
  });

  final List<PlayerOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: 1,
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final option = options[index];
                return _SidePanelOptionTile(
                  label: option.label,
                  selected: option.value == selectedValue,
                  onTap: () => onSelected(option.value),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class EpisodeSidePanel extends StatelessWidget {
  const EpisodeSidePanel({
    super.key,
    required this.title,
    required this.strings,
    required this.videos,
    required this.currentIndex,
    required this.onSelected,
  });

  final String title;
  final ExampleStrings strings;
  final List<String> videos;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.42,
        heightFactor: 1,
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      TextSpan(
                        text: strings.episodeCount(videos.length),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: videos.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 24, color: Color(0x26FFFFFF)),
                    itemBuilder: (context, index) {
                      return _EpisodeTile(
                        index: index,
                        title: videos[index],
                        strings: strings,
                        selected: index == currentIndex,
                        onTap: () => onSelected(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanelOptionTile extends StatelessWidget {
  const _SidePanelOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 74,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 34),
        decoration: BoxDecoration(
          color: const Color(0xE62A2B31),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFFFF6FA8) : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.index,
    required this.title,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String title;
  final ExampleStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFF6FA8) : Colors.white;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            Container(
              width: 138,
              height: 78,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? const [Color(0xFF3D2430), Color(0xFF111111)]
                      : const [Color(0xFF3B3E45), Color(0xFF17191D)],
                ),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      height: 1.18,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    selected
                        ? strings.nowPlayingLabel
                        : strings.episodeNumber(index + 1),
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? color : Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
