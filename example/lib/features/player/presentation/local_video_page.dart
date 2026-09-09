import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:player_m3u8/player_m3u8.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../shared/localization/example_strings.dart';
import 'player_video_scaffold.dart';

class LocalVideoPage extends StatefulWidget {
  const LocalVideoPage({super.key});

  @override
  State<LocalVideoPage> createState() => _LocalVideoPageState();
}

class _LocalVideoPageState extends State<LocalVideoPage> {
  String? _fileName;
  bool _importing = false;
  String? _errorMessage;
  final List<File> _library = <File>[];
  static const _libraryKey = 'local_video_library_paths';

  @override
  void initState() {
    super.initState();
    _restoreLibrary();
  }

  Future<void> _restoreLibrary() async {
    final preferences = await SharedPreferences.getInstance();
    final paths = preferences.getStringList(_libraryKey) ?? <String>[];
    final files =
        paths.map(File.new).where((file) => file.existsSync()).toList()..sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );
    if (mounted) setState(() => _library.addAll(files));
  }

  Future<void> _persistLibrary() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _libraryKey,
      _library.map((file) => file.path).toList(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _errorMessage = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null || path.isEmpty || !mounted) return;
      final pickedName = result!.files.single.name;
      final file = File(path);
      if (!await file.exists()) {
        throw StateError('选择的视频文件不存在或无法读取。');
      }
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/imported_videos');
      await directory.create(recursive: true);
      final safeName = pickedName.replaceAll(RegExp(r'[/\\]'), '_');
      final imported = await file.copy(
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName',
      );
      final sourceLength = await file.length();
      final importedLength = await imported.length();
      debugPrint(
        'LocalVideoPage import sourcePath=${file.path} '
        'sourceBytes=$sourceLength importedPath=${imported.path} '
        'importedBytes=$importedLength',
      );
      if (!await imported.exists() ||
          importedLength == 0 ||
          sourceLength != importedLength) {
        throw StateError('导入文件为空或无法读取。');
      }
      setState(() {
        _fileName = pickedName;
        _library.removeWhere((item) => item.path == imported.path);
        _library.add(imported);
        _library.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );
      });
      await _persistLibrary();
    } catch (error) {
      debugPrint('LocalVideoPage import failed: $error');
      if (mounted) {
        final message = error is StateError ? '该文件不符合播放格式' : '文件导入失败';
        setState(() => _errorMessage = message);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本地视频播放')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _pickVideo,
        icon: const Icon(Icons.file_upload_outlined),
        label: const Text('导入'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: FilledButton.icon(
                onPressed: _importing ? null : _pickVideo,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('导入视频'),
              ),
            ),
          ),
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_library.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: _library.length,
                itemBuilder: (context, index) {
                  final file = _library[index];
                  final stat = file.statSync();
                  return Card(
                    child: ListTile(
                      isThreeLine: true,
                      leading: _VideoThumbnail(file: file),
                      title: Text(
                        file.uri.pathSegments.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatBytes(stat.size)}  ${_formatDate(stat.modified)}',
                          ),
                          Text('格式：${_videoFormat(file)}'),
                          Text(
                            '路径：${file.path}',
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'delete') {
                            final removed = _library.removeAt(index);
                            setState(() {});
                            await removed.delete().catchError((_) => removed);
                            await _persistLibrary();
                          } else {
                            await _openPlayer(file);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'play', child: Text('播放')),
                          PopupMenuItem(value: 'delete', child: Text('删除记录')),
                        ],
                      ),
                      onTap: () => _openPlayer(file),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openPlayer(File file) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => LocalVideoPlayerPage(file: file)),
    );
  }

  String _formatBytes(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _videoFormat(File file) {
    final name = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '未知';
    return name.substring(dot + 1).toUpperCase();
  }
}

class LocalVideoPlayerPage extends StatefulWidget {
  const LocalVideoPlayerPage({required this.file, super.key});

  final File file;

  @override
  State<LocalVideoPlayerPage> createState() => _LocalVideoPlayerPageState();
}

class _LocalVideoPlayerPageState extends State<LocalVideoPlayerPage> {
  late final M3u8PlayerController _controller = M3u8PlayerController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _enterImmersiveMode();
    _initialize();
  }

  Future<void> _enterImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize(
        source: M3u8Source.file(widget.file.path),
        autoPlay: false,
      );
    } catch (_) {
      if (mounted) setState(() => _error = '该文件不符合播放格式');
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
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
          return ExampleVideoScaffold(
            controller: _controller,
            value: value,
            title: widget.file.uri.pathSegments.last,
            episodes: const <String>[],
            currentEpisodeIndex: 0,
            sourceType: M3u8SourceType.progressive,
            strings: const ExampleStrings(ExampleLanguage.zh),
            isFullscreen: true,
            controlsLocked: false,
            isBusy: false,
            isPrecacheRunning: false,
            precacheSupported: false,
            autoPlayNext: false,
            loopMode: ExampleLoopMode.none,
            onBack: () => Navigator.of(context).pop(),
            onEnterFullscreen: () {},
            onExitFullscreen: () => Navigator.of(context).pop(),
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

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 112,
        quality: 70,
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const SizedBox(
            width: 56,
            height: 56,
            child: ColoredBox(
              color: Colors.black12,
              child: Icon(Icons.video_file_outlined),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
        );
      },
    );
  }
}
