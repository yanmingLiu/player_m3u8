import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:player_m3u8/player_m3u8.dart';

import '../../../shared/localization/example_strings.dart';
import 'standalone_video_scaffold.dart';

/// 一个可独立使用的全屏播放器页面。
///
/// [url] 可以是 http/https 地址、文件路径或 file:// URI。
class StandaloneVideoPlayerPage extends StatefulWidget {
  const StandaloneVideoPlayerPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<StandaloneVideoPlayerPage> createState() =>
      _StandaloneVideoPlayerPageState();
}

class _StandaloneVideoPlayerPageState extends State<StandaloneVideoPlayerPage> {
  late final M3u8PlayerController _controller = M3u8PlayerController();
  String? _error;

  bool get _isNetworkUrl {
    final scheme = Uri.tryParse(widget.url)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  M3u8Source get _source {
    if (_isNetworkUrl) return M3u8Source(videoUrl: widget.url);
    final uri = Uri.tryParse(widget.url);
    final path = uri?.scheme.toLowerCase() == 'file'
        ? uri!.toFilePath()
        : widget.url;
    return M3u8Source.file(path);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_enterFullscreenPortrait());
    unawaited(_initialize());
  }

  Future<void> _enterFullscreenPortrait() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize(source: _source, autoPlay: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const []));
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<M3u8PlayerValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          if (_error != null) {
            return Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            );
          }
          if (!value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return StandaloneVideoScaffold(
            controller: _controller,
            value: value,
            title: widget.title ?? widget.url,
            episodes: const [],
            currentEpisodeIndex: 0,
            sourceType: _isNetworkUrl
                ? M3u8SourceType.auto
                : M3u8SourceType.progressive,
            strings: const ExampleStrings(ExampleLanguage.zh),
            isFullscreen: true,
            controlsLocked: false,
            isBusy: false,
            isPrecacheRunning: false,
            precacheSupported: false,
            autoPlayNext: false,
            loopMode: StandaloneLoopMode.none,
            onBack: () => Navigator.of(context).maybePop(),
            onEnterFullscreen: () {},
            onExitFullscreen: () => Navigator.of(context).maybePop(),
            onControlsLockedChanged: (_) {},
            onEpisodeSelected: (_) {},
            onPrecache: () {},
            onShowDownloads: () {},
            onSpeedSelected: _controller.setPlaybackSpeed,
            onAutoPlayNextChanged: (_) {},
            onLoopModeChanged: (_) {},
          );
        },
      ),
    );
  }
}
