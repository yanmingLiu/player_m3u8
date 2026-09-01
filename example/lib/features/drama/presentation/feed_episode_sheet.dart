import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/drama_models.dart';
import 'drama_cover_image.dart';

/// The episode picker shown above the vertical drama player.
///
/// The sheet returns the selected episode index through the surrounding
/// [showModalBottomSheet]. Keeping that contract means selecting an episode
/// still uses the same source-switching path as the player controls.
class FeedEpisodeSheet extends StatefulWidget {
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
  State<FeedEpisodeSheet> createState() => _FeedEpisodeSheetState();
}

class _FeedEpisodeSheetState extends State<FeedEpisodeSheet> {
  static const panelColor = Color(0xff32252b);
  static const accentColor = Color(0xffe96b82);
  static const accentStrongColor = Color(0xffe14c67);
  static const accentSoftColor = Color(0xfff1a2b1);
  static const secondaryTextColor = Color(0xffc3b5bb);
  static const tileColor = Color(0x1affffff);

  late final PageController _tabsPageController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabsPageController = PageController();
  }

  @override
  void dispose() {
    _tabsPageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTab != index) {
      setState(() => _selectedTab = index);
    }
    final page = _tabsPageController.page;
    if (_tabsPageController.hasClients &&
        (page == null || (page - index).abs() > 0.01)) {
      _tabsPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handlePageChanged(int index) {
    if (_selectedTab != index) {
      setState(() => _selectedTab = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final initialSize = (500 / screenHeight).clamp(0.45, 0.92).toDouble();

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialSize,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Stack(
              children: [
                ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _header(),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _tabs(),
                    ),
                    const SizedBox(height: 16),
                    _contentPager(),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: accentSoftColor,
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    tooltip: 'Close',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    final episode = widget.episodes.isEmpty ? null : widget.episodes.first;
    return SizedBox(
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 108,
              child: episode == null
                  ? const ColoredBox(
                      color: tileColor,
                      child: Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: secondaryTextColor,
                        ),
                      ),
                    )
                  : DramaCoverImage(
                      url: episode.cover,
                      fit: BoxFit.cover,
                      semanticLabel: widget.series.title,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.series.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MetaRow(icon: Icons.person, text: '@ namename'),
                      SizedBox(width: 10),
                      _MetaRow(icon: Icons.favorite, text: '12344'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Row(
      children: [
        _tab(label: 'Episodes', index: 0),
        SizedBox(width: 24),
        _tab(label: 'Synopsis', index: 1),
      ],
    );
  }

  Widget _tab({required String label, required int index}) {
    final selected = _selectedTab == index;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => _selectTab(index),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? (index == 0 ? accentColor : accentSoftColor)
                      : secondaryTextColor,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  height: 1.35,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: selected ? 72 : 0,
                height: 2,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentPager() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final contentHeight = math.max(
          _episodesGridHeight(width),
          _synopsisHeight(context, width),
        );
        return SizedBox(
          height: contentHeight,
          child: PageView(
            controller: _tabsPageController,
            onPageChanged: _handlePageChanged,
            children: [_episodesGrid(), _synopsis()],
          ),
        );
      },
    );
  }

  double _episodesGridHeight(double availableWidth) {
    if (widget.episodes.isEmpty) {
      return 0;
    }
    final gridWidth = math.min(math.max(availableWidth - 32, 0), 328.0);
    final tileSize = (gridWidth - (5 * 8)) / 6;
    final rowCount = (widget.episodes.length + 5) ~/ 6;
    return (rowCount * tileSize) + ((rowCount - 1) * 8);
  }

  double _synopsisHeight(BuildContext context, double availableWidth) {
    final description = widget.series.description.trim();
    final text = description.isEmpty ? 'No synopsis available.' : description;
    final style = const TextStyle(
      color: secondaryTextColor,
      fontSize: 14,
      height: 1.35,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: availableWidth);
    return (16 * 1.25) + 12 + painter.height;
  }

  Widget _episodesGrid() {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.episodes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) => _episodeTile(index),
        ),
      ),
    );
  }

  Widget _episodeTile(int index) {
    final episode = widget.episodes[index];
    final selected = index == widget.currentIndex;
    final locked = index != 0 && !selected;
    final numberColor = selected || !locked ? Colors.white : accentStrongColor;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Episode ${episode.number}${locked ? ', locked' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(index),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: locked ? const Color(0xff685660) : tileColor,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
            ),
            child: Center(
              child: locked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 15,
                          color: accentStrongColor,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${episode.number}',
                          style: TextStyle(
                            color: numberColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${episode.number}',
                      style: TextStyle(
                        color: numberColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _synopsis() {
    final description = widget.series.description.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this Drama',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description.isEmpty ? 'No synopsis available.' : description,
            style: const TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _FeedEpisodeSheetState.accentSoftColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: _FeedEpisodeSheetState.accentSoftColor,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
