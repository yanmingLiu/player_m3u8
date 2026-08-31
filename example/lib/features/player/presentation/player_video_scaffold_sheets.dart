part of 'player_video_scaffold.dart';

class PortraitMoreSheet {
  const PortraitMoreSheet._();

  static Future<void> show({
    required BuildContext context,
    required M3u8PlayerValue value,
    required bool isPrecacheRunning,
    required bool precacheSupported,
    required bool autoPlayNext,
    required ExampleLoopMode loopMode,
    required VoidCallback onPrecache,
    required VoidCallback onShowDownloads,
    required ValueChanged<double> onSpeedSelected,
    required ValueChanged<bool> onAutoPlayNextChanged,
    required ValueChanged<ExampleLoopMode> onLoopModeChanged,
    required ExampleStrings strings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _PortraitMoreSheetBody(
          value: value,
          isPrecacheRunning: isPrecacheRunning,
          precacheSupported: precacheSupported,
          autoPlayNext: autoPlayNext,
          loopMode: loopMode,
          onPrecache: onPrecache,
          onShowDownloads: onShowDownloads,
          onSpeedSelected: onSpeedSelected,
          onAutoPlayNextChanged: onAutoPlayNextChanged,
          onLoopModeChanged: onLoopModeChanged,
          strings: strings,
        );
      },
    );
  }
}

class LandscapeMorePanel extends StatelessWidget {
  LandscapeMorePanel({
    super.key,
    required M3u8PlayerValue value,
    required bool isPrecacheRunning,
    required bool precacheSupported,
    required bool autoPlayNext,
    required ExampleLoopMode loopMode,
    required VoidCallback onPrecache,
    required VoidCallback onShowDownloads,
    required ValueChanged<double> onSpeedSelected,
    required ValueChanged<bool> onAutoPlayNextChanged,
    required ValueChanged<ExampleLoopMode> onLoopModeChanged,
    required ExampleStrings strings,
  }) : _body = _LandscapeMorePanelBody(
         value: value,
         isPrecacheRunning: isPrecacheRunning,
         precacheSupported: precacheSupported,
         autoPlayNext: autoPlayNext,
         loopMode: loopMode,
         onPrecache: onPrecache,
         onShowDownloads: onShowDownloads,
         onSpeedSelected: onSpeedSelected,
         onAutoPlayNextChanged: onAutoPlayNextChanged,
         onLoopModeChanged: onLoopModeChanged,
         strings: strings,
       );

  final _LandscapeMorePanelBody _body;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.42,
        heightFactor: 1,
        child: Material(color: Colors.black, child: _body),
      ),
    );
  }
}

class _PortraitMoreSheetBody extends StatefulWidget {
  const _PortraitMoreSheetBody({
    required this.value,
    required this.isPrecacheRunning,
    required this.precacheSupported,
    required this.autoPlayNext,
    required this.loopMode,
    required this.onPrecache,
    required this.onShowDownloads,
    required this.onSpeedSelected,
    required this.onAutoPlayNextChanged,
    required this.onLoopModeChanged,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final bool isPrecacheRunning;
  final bool precacheSupported;
  final bool autoPlayNext;
  final ExampleLoopMode loopMode;
  final VoidCallback onPrecache;
  final VoidCallback onShowDownloads;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onAutoPlayNextChanged;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  final ExampleStrings strings;

  @override
  State<_PortraitMoreSheetBody> createState() => _PortraitMoreSheetBodyState();
}

class _PortraitMoreSheetBodyState extends State<_PortraitMoreSheetBody> {
  late bool _autoPlayNext = widget.autoPlayNext;
  late ExampleLoopMode _loopMode = widget.loopMode;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6F7F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D2D6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MoreActionButton(
                    icon: Icons.download_done_outlined,
                    label: widget.strings.notInterestedLabel,
                    onPressed: widget.onShowDownloads,
                  ),
                  _MoreActionButton(
                    icon: Icons.replay_circle_filled_outlined,
                    label: widget.strings.watchLaterLabel,
                    onPressed: () {},
                  ),
                  _MoreActionButton(
                    icon: Icons.download_for_offline_outlined,
                    label: widget.isPrecacheRunning
                        ? widget.strings.cachingLabel
                        : widget.strings.cacheLabel,
                    onPressed:
                        widget.precacheSupported && !widget.isPrecacheRunning
                        ? widget.onPrecache
                        : null,
                  ),
                  _MoreActionButton(
                    icon: Icons.picture_in_picture_alt_outlined,
                    label: widget.strings.pipLabel,
                    onPressed: () {},
                  ),
                  _MoreActionButton(
                    icon: Icons.connected_tv_outlined,
                    label: widget.strings.castLabel,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MoreSettingsCard(
                foregroundColor: Colors.black87,
                dividerColor: const Color(0xFFE7E8EC),
                children: [
                  _SpeedSettingRow(
                    value: widget.value,
                    onSpeedSelected: widget.onSpeedSelected,
                    isDark: false,
                    strings: widget.strings,
                  ),
                  _SwitchSettingRow(
                    icon: Icons.skip_next,
                    label: widget.strings.autoPlayNextLabel,
                    value: _autoPlayNext,
                    onChanged: _setAutoPlayNext,
                    isDark: false,
                  ),
                  _LoopSettingRow(
                    loopMode: _loopMode,
                    onLoopModeChanged: _setLoopMode,
                    isDark: false,
                    strings: widget.strings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setAutoPlayNext(bool value) {
    setState(() {
      _autoPlayNext = value;
    });
    widget.onAutoPlayNextChanged(value);
  }

  void _setLoopMode(ExampleLoopMode mode) {
    setState(() {
      _loopMode = mode;
    });
    widget.onLoopModeChanged(mode);
  }
}

class _LandscapeMorePanelBody extends StatefulWidget {
  const _LandscapeMorePanelBody({
    required this.value,
    required this.isPrecacheRunning,
    required this.precacheSupported,
    required this.autoPlayNext,
    required this.loopMode,
    required this.onPrecache,
    required this.onShowDownloads,
    required this.onSpeedSelected,
    required this.onAutoPlayNextChanged,
    required this.onLoopModeChanged,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final bool isPrecacheRunning;
  final bool precacheSupported;
  final bool autoPlayNext;
  final ExampleLoopMode loopMode;
  final VoidCallback onPrecache;
  final VoidCallback onShowDownloads;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<bool> onAutoPlayNextChanged;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  final ExampleStrings strings;

  @override
  State<_LandscapeMorePanelBody> createState() =>
      _LandscapeMorePanelBodyState();
}

class _LandscapeMorePanelBodyState extends State<_LandscapeMorePanelBody> {
  late bool _autoPlayNext = widget.autoPlayNext;
  late ExampleLoopMode _loopMode = widget.loopMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MoreActionButton(
                icon: Icons.download_done_outlined,
                label: widget.strings.downloadListLabel,
                isDark: true,
                onPressed: widget.onShowDownloads,
              ),
              _MoreActionButton(
                icon: Icons.replay_circle_filled_outlined,
                label: widget.strings.watchLaterLabel,
                isDark: true,
                onPressed: () {},
              ),
              _MoreActionButton(
                icon: Icons.download_for_offline_outlined,
                label: widget.isPrecacheRunning
                    ? widget.strings.cachingLabel
                    : widget.strings.cacheLabel,
                isDark: true,
                onPressed: widget.precacheSupported && !widget.isPrecacheRunning
                    ? widget.onPrecache
                    : null,
              ),
              _MoreActionButton(
                icon: Icons.connected_tv_outlined,
                label: widget.strings.castLabel,
                isDark: true,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SpeedSettingRow(
            value: widget.value,
            onSpeedSelected: widget.onSpeedSelected,
            isDark: true,
            strings: widget.strings,
          ),
          const SizedBox(height: 14),
          _MoreSettingsCard(
            foregroundColor: Colors.white,
            dividerColor: const Color(0x22FFFFFF),
            backgroundColor: const Color(0xD9222328),
            children: [
              _SwitchSettingRow(
                icon: Icons.skip_next,
                label: widget.strings.autoPlayNextLabel,
                value: _autoPlayNext,
                onChanged: _setAutoPlayNext,
                isDark: true,
              ),
              _LoopSettingRow(
                loopMode: _loopMode,
                onLoopModeChanged: _setLoopMode,
                isDark: true,
                strings: widget.strings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setAutoPlayNext(bool value) {
    setState(() {
      _autoPlayNext = value;
    });
    widget.onAutoPlayNextChanged(value);
  }

  void _setLoopMode(ExampleLoopMode mode) {
    setState(() {
      _loopMode = mode;
    });
    widget.onLoopModeChanged(mode);
  }
}

class _MoreActionButton extends StatelessWidget {
  const _MoreActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDark = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = isDark ? Colors.white : Colors.black;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: enabled ? color : color.withValues(alpha: 0.32),
          iconSize: isDark ? 25 : 27,
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xCC24262C)
                : const Color(0xFFFFFFFF),
            fixedSize: isDark ? const Size(52, 48) : const Size(56, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: enabled ? 0.68 : 0.32),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MoreSettingsCard extends StatelessWidget {
  const _MoreSettingsCard({
    required this.children,
    required this.foregroundColor,
    required this.dividerColor,
    this.backgroundColor = Colors.white,
  });

  final List<Widget> children;
  final Color foregroundColor;
  final Color dividerColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: foregroundColor, size: 25),
      child: DefaultTextStyle(
        style: TextStyle(color: foregroundColor, fontSize: 18),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, indent: 54, color: dividerColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedSettingRow extends StatelessWidget {
  const _SpeedSettingRow({
    required this.value,
    required this.onSpeedSelected,
    required this.isDark,
    required this.strings,
  });

  final M3u8PlayerValue value;
  final ValueChanged<double> onSpeedSelected;
  final bool isDark;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    const speeds = <double>[0.75, 1.0, 1.5, 2.0];
    final selected = nearestSpeed(value.playbackSpeed, speeds);
    final color = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Icon(Icons.fast_forward, color: color),
          const SizedBox(width: 10),
          Text(
            strings.playbackSpeedLabel,
            style: TextStyle(color: color, fontSize: 16),
          ),
          const Spacer(),
          for (final speed in speeds) ...[
            TextButton(
              onPressed: () => onSpeedSelected(speed),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                speedLabel(speed),
                style: TextStyle(
                  color: speed == selected
                      ? const Color(0xFFFF5C93)
                      : color.withValues(alpha: 0.58),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 16)),
          const Spacer(),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFF5C93),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LoopSettingRow extends StatelessWidget {
  const _LoopSettingRow({
    required this.loopMode,
    required this.onLoopModeChanged,
    required this.isDark,
    required this.strings,
  });

  final ExampleLoopMode loopMode;
  final ValueChanged<ExampleLoopMode> onLoopModeChanged;
  final bool isDark;
  final ExampleStrings strings;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.loop, color: color),
          const SizedBox(width: 10),
          Text(
            strings.loopPlaybackLabel,
            style: TextStyle(color: color, fontSize: 16),
          ),
          const Spacer(),
          _LoopModeButton(
            label: strings.singleLoopLabel,
            selected: loopMode == ExampleLoopMode.single,
            onPressed: () => onLoopModeChanged(ExampleLoopMode.single),
            isDark: isDark,
          ),
          _LoopModeButton(
            label: strings.playlistLoopLabel,
            selected: loopMode == ExampleLoopMode.playlist,
            onPressed: () => onLoopModeChanged(ExampleLoopMode.playlist),
            isDark: isDark,
          ),
          _LoopModeButton(
            label: strings.noLoopLabel,
            selected: loopMode == ExampleLoopMode.none,
            onPressed: () => onLoopModeChanged(ExampleLoopMode.none),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _LoopModeButton extends StatelessWidget {
  const _LoopModeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        minimumSize: const Size(36, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: selected
              ? const Color(0xFFFF5C93)
              : (isDark ? Colors.white60 : Colors.black45),
          fontSize: 12,
        ),
      ),
    );
  }
}
