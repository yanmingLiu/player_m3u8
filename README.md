# player_m3u8

[中文](#中文) | [English](#english)

## 中文

`player_m3u8` 是一个 Flutter HLS/m3u8 播放插件，支持 iOS 和 Android，使用 Flutter `Texture` 渲染视频画面。Android 基于 Media3 ExoPlayer，iOS 基于 AVFoundation。

适合需要播放网络 HLS/m3u8 VOD 或 MP4/MOV、展示播放进度/缓冲进度、切换播放列表、做磁盘预缓存的 Flutter 应用。

### 功能

- 播放网络 HLS/m3u8，以及 progressive MP4/MOV。
- 播放、暂停、seek、快进/快退、倍速、音量、静音、错误重试。
- 通过 `M3u8PlayerController.setSource(...)` 切换播放源。
- 监听播放状态、播放进度、时长、缓冲、磁盘缓存、错误。
- HLS 清晰度列表和 Auto/手动清晰度选择。
- HLS 内嵌字幕和外部 WebVTT 字幕。
- HLS 当前视频磁盘预取，seek 后会从新位置继续优先预取。
- 可选播放区域手势层：左侧上下滑动调节亮度，右侧上下滑动调节播放器内音量，左右滑动调节进度。
- 播放健康指标：首帧耗时、rebuffer 次数、rebuffer 总时长、丢帧数、当前码率、观测带宽、清晰度切换次数。

更详细的平台实现、缓存规则和架构图见 [ARCHITECTURE.md](ARCHITECTURE.md)。

### 安装

```sh
flutter pub add player_m3u8
```

然后在 Dart 文件中导入：

```dart
import 'package:player_m3u8/player_m3u8.dart';
```

### 最小接入示例

下面是一个可以直接放进 Flutter 页面里的完整示例。真实业务中只需要把 `videoUrl` 换成自己的 HLS/m3u8 地址。

```dart
import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final M3u8PlayerController _controller = M3u8PlayerController();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _controller.initialize(
      source: const M3u8Source(
        videoUrl: 'https://example.com/index.m3u8',
      ),
      autoPlay: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('player_m3u8')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: M3u8Player(controller: _controller),
          ),
          ValueListenableBuilder<M3u8PlayerValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final durationMs = value.duration.inMilliseconds;
              final progress = durationMs <= 0
                  ? 0.0
                  : value.position.inMilliseconds / durationMs;

              return Column(
                children: [
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                  ),
                  Text('${value.position} / ${value.duration}'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: value.isPlaying
                            ? _controller.pause
                            : _controller.play,
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: () =>
                            _controller.seekBy(const Duration(seconds: -10)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed: () =>
                            _controller.seekBy(const Duration(seconds: 10)),
                      ),
                    ],
                  ),
                  if (value.isBuffering) const Text('缓冲中...'),
                  if (value.error != null)
                    Text('播放错误：${value.error!.message}'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### 监听播放状态和进度

`M3u8PlayerController` 本身是 `ValueNotifier<M3u8PlayerValue>`，推荐用 `ValueListenableBuilder` 刷新 UI：

```dart
ValueListenableBuilder<M3u8PlayerValue>(
  valueListenable: controller,
  builder: (context, value, _) {
    return Text(
      'playing=${value.isPlaying}, '
      'position=${value.position}, '
      'duration=${value.duration}, '
      'buffered=${value.bufferedPosition}',
    );
  },
);
```

也可以手动监听：

```dart
controller.addListener(() {
  final value = controller.value;
  debugPrint('position=${value.position}, buffering=${value.isBuffering}');
});
```

常用字段：`isInitialized`、`isPlaying`、`isBuffering`、`isCompleted`、`position`、`duration`、`bufferedPosition`、`diskCachePosition`、`diskCachePercent`、`availableQualities`、`selectedQuality`、`availableSubtitles`、`selectedSubtitle`、`subtitleText`、`availableAudioTracks`、`selectedAudioTrack`、`playbackSpeed`、`volume`、`isMuted`、`size`、`error`。

### 播放控制

```dart
await controller.play();
await controller.pause();
await controller.seekTo(const Duration(minutes: 1));
await controller.seekBy(const Duration(seconds: 15));
await controller.setPlaybackSpeed(1.25);
await controller.setVolume(0.8);
await controller.setMuted(true);
await controller.retry();
```

`seekBy` 会自动裁剪到 `0..duration` 范围内。

### 可选手势层

`M3u8Player` 默认不启用手势。需要播放区域手势时，显式包一层 `M3u8PlayerGestureControls`：

```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: M3u8PlayerGestureControls(
    controller: controller,
    child: M3u8Player(controller: controller),
  ),
)
```

内置手势：

- 左侧上下滑动：调节屏幕亮度。Android 调节当前 Activity window 亮度，iOS 调节 `UIScreen.main.brightness`。
- 右侧上下滑动：调节当前播放器内音量，等同于调用 `controller.setVolume(...)`。
- 左右滑动：预览目标进度，并在松手后调用 `controller.seekTo(...)`。

如果业务已经有自己的手势层，可以不使用这个组件。也可以通过配置关闭整体或单项能力：

```dart
M3u8PlayerGestureControls(
  controller: controller,
  config: const M3u8GestureControlsConfig(
    brightnessEnabled: true,
    volumeEnabled: true,
    seekEnabled: true,
    brightnessOverlayEnabled: true,
  ),
  child: M3u8Player(controller: controller),
)
```

`brightnessOverlayEnabled` 是亮度遮罩兜底；在模拟器或系统亮度 API 不明显时，播放区域仍会有可见的明暗反馈。

### 切换播放源

列表、短视频流或剧集切换时，使用 `setSource(...)`：

```dart
await controller.setSource(
  const M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
);
```

切换 source 时插件会释放旧 native player，并取消旧 source 的播放器内部主动预取；旧 source 已经写入磁盘的数据可以保留复用。

### 播放 MP4/MOV

MP4/MOV 会在默认 `sourceType: M3u8SourceType.auto` 下按后缀自动识别。如果 URL 没有标准后缀，可以显式传入：

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/video.mp4',
    sourceType: M3u8SourceType.progressive,
  ),
  autoPlay: true,
);
```

### 请求头和缓存 key

如果视频接口需要请求头：

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/index.m3u8',
    videoHeaders: {'Authorization': 'Bearer token'},
  ),
);
```

默认缓存 key 会包含 URL 和 headers，避免不同用户、不同鉴权或不同地区的资源互相复用。如果业务 URL 是短期签名地址，但实际指向同一个不可变视频，可以传入稳定的业务 key。不要把用户敏感信息写入 `cacheKey`。

```dart
const source = M3u8Source(
  videoUrl: 'https://example.com/index.m3u8?token=short-lived',
  cacheKey: 'course-123-lesson-4',
);
```

### 字幕和音频轨道

外部 WebVTT 字幕可以在初始化或切换 source 时传入：

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  subtitles: const [
    M3u8SubtitleTrack(
      id: 'zh',
      label: '中文',
      language: 'zh',
      url: 'https://example.com/subtitles/zh.vtt',
      mimeType: 'text/vtt',
    ),
  ],
  selectedSubtitleId: 'zh',
);

await controller.setSubtitle('zh');
await controller.clearSubtitle();
```

HLS 多音轨会通过 `value.availableAudioTracks` 上报：

```dart
await controller.setAudioTrack('en');
await controller.clearAudioTrack();
```

如果视频和音频是分开的 HLS 流，可以传入 `audioUrl`。iOS 外部字幕当前只对 HLS source 暴露；progressive MP4/MOV 在 iOS 上不会上报外部字幕列表。

### 清晰度选择

```dart
final qualities = controller.value.availableQualities;

await controller.setQuality(M3u8Quality.auto);

if (qualities.isNotEmpty) {
  await controller.setQuality(qualities.first);
}
```

Android 会通过 ExoPlayer track selector 约束播放清晰度。iOS HLS 主播放链路保持 direct `AVPlayer`，手动清晰度属于 best-effort，最终播放选择仍由 AVPlayer ABR 决定。

### 独立预缓存

如果想在播放前或播放外单独下载资源，使用 `M3u8PlayerCache.precache(...)`：

```dart
final source = const M3u8Source(
  videoUrl: 'https://example.com/index.m3u8',
);

final taskId = await M3u8PlayerCache.precache(source);

final subscription = M3u8PlayerCache.events().listen((event) {
  if (event.taskId != taskId) {
    return;
  }

  final progress = event.bytesTotal <= 0
      ? event.byteProgress
      : event.bytesCached / event.bytesTotal;

  debugPrint(
    'status=${event.status}, progress=${(progress * 100).toStringAsFixed(1)}%',
  );
});

await M3u8PlayerCache.cancelPrecache(taskId);
await subscription.cancel();
```

常用缓存 API：

```dart
await M3u8PlayerCache.configure(
  maxSizeBytes: 1024 * 1024 * 1024,
  maxConcurrentPrecacheTasks: 2,
);

final info = await M3u8PlayerCache.info();
final tasks = await M3u8PlayerCache.tasks();
final sourceInfo = await M3u8PlayerCache.sourceInfo(source);

await M3u8PlayerCache.pausePrecache(taskId);
await M3u8PlayerCache.resumePrecache(taskId);
await M3u8PlayerCache.cancelPrecache(taskId);
await M3u8PlayerCache.clearSource(source);
```

缓存容量配置和全量清理要求当前没有活跃 native player 或独立下载任务。只调整 `maxConcurrentPrecacheTasks` 可以在运行期调用。

### QoE 快照

```dart
controller.startQoeSampling(interval: const Duration(seconds: 5));

final subscription = controller.qoeSnapshots.listen((snapshot) {
  debugPrint(snapshot.toMap().toString());
});
```

`M3u8QoeSnapshot` 包含当前播放位置、缓冲位置、磁盘缓存位置、首帧耗时、rebuffer 次数和窗口增量、rebuffer 总时长和窗口增量、丢帧增量、恢复增量、清晰度切换增量、当前码率、观测带宽、当前清晰度和播放倍速。

### 当前限制

- 只支持 iOS 和 Android。
- 支持网络 HLS/m3u8 VOD 和 progressive MP4/MOV；不支持 DASH、SmoothStreaming、RTSP、FLV 或本地文件。
- MP4/MOV 支持独立完整下载和完成后缓存复用，但不支持清晰度选择。
- Android progressive 可以挂外部字幕，iOS progressive 暂不暴露外部字幕。
- iOS HLS 播放由 AVFoundation direct `AVPlayer` 负责；HLS 手动清晰度是 best-effort。
- iOS HLS 磁盘预取只承诺常见 VOD playlist。live/event playlist、`#EXT-X-BYTERANGE`、I-frame-only playlist、复杂加密或 DRM playlist 会返回 `unsupported_hls_playlist` 缓存错误，播放链路不因此失败。
- 原生层不承诺 app 重启后恢复未完成下载队列；如果业务需要下载列表持久化，可以参考 example 的做法。

### 示例工程

仓库内的 `example` 包含播放、暂停、seek、播放列表切换、清晰度、字幕、音轨、独立预缓存、下载列表、QoE 面板等完整用法。

```sh
cd example
flutter run
```

### 本地验证

```sh
flutter analyze
flutter test
cd example && flutter test
```

涉及原生代码时额外运行：

```sh
cd example/android && ./gradlew testDebugUnitTest
cd ../.. && cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
```

## English

`player_m3u8` is a Flutter HLS/m3u8 player plugin for iOS and Android. It renders video through Flutter `Texture`. Android uses Media3 ExoPlayer, and iOS uses AVFoundation.

It is designed for Flutter apps that need network HLS/m3u8 VOD or MP4/MOV playback, playback and buffer progress UI, playlist switching, and disk precache.

### Features

- Network HLS/m3u8 playback plus progressive MP4/MOV playback.
- Play, pause, seek, skip back/forward, speed, volume, mute, retry, and dispose.
- Playlist switching through `M3u8PlayerController.setSource(...)`.
- Playback state, progress, duration, buffer, disk cache, and error listening.
- HLS quality list with Auto/manual quality selection.
- Built-in HLS subtitles and external WebVTT subtitles.
- Current-source HLS disk prefetch; after seek, prefetch restarts near the new playback position.
- Optional player-area gesture layer: vertical drags on the left adjust brightness, vertical drags on the right adjust player volume, and horizontal drags seek.
- Playback health metrics: startup time, rebuffer count and duration, dropped frames, current bitrate, observed bandwidth, and quality switch count.

See [ARCHITECTURE.md](ARCHITECTURE.md) for platform internals, cache rules, and architecture diagrams.

### Installation

```sh
flutter pub add player_m3u8
```

Import it in Dart:

```dart
import 'package:player_m3u8/player_m3u8.dart';
```

### Minimal Setup

This complete page can be pasted into a Flutter app. Replace `videoUrl` with your HLS/m3u8 URL.

```dart
import 'package:flutter/material.dart';
import 'package:player_m3u8/player_m3u8.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final M3u8PlayerController _controller = M3u8PlayerController();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _controller.initialize(
      source: const M3u8Source(
        videoUrl: 'https://example.com/index.m3u8',
      ),
      autoPlay: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('player_m3u8')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: M3u8Player(controller: _controller),
          ),
          ValueListenableBuilder<M3u8PlayerValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final durationMs = value.duration.inMilliseconds;
              final progress = durationMs <= 0
                  ? 0.0
                  : value.position.inMilliseconds / durationMs;

              return Column(
                children: [
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                  ),
                  Text('${value.position} / ${value.duration}'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: value.isPlaying
                            ? _controller.pause
                            : _controller.play,
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: () =>
                            _controller.seekBy(const Duration(seconds: -10)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed: () =>
                            _controller.seekBy(const Duration(seconds: 10)),
                      ),
                    ],
                  ),
                  if (value.isBuffering) const Text('Buffering...'),
                  if (value.error != null)
                    Text('Playback error: ${value.error!.message}'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Listen To State And Progress

`M3u8PlayerController` is a `ValueNotifier<M3u8PlayerValue>`. Use `ValueListenableBuilder` to refresh UI:

```dart
ValueListenableBuilder<M3u8PlayerValue>(
  valueListenable: controller,
  builder: (context, value, _) {
    return Text(
      'playing=${value.isPlaying}, '
      'position=${value.position}, '
      'duration=${value.duration}, '
      'buffered=${value.bufferedPosition}',
    );
  },
);
```

Manual listener:

```dart
controller.addListener(() {
  final value = controller.value;
  debugPrint('position=${value.position}, buffering=${value.isBuffering}');
});
```

Common fields: `isInitialized`, `isPlaying`, `isBuffering`, `isCompleted`, `position`, `duration`, `bufferedPosition`, `diskCachePosition`, `diskCachePercent`, `availableQualities`, `selectedQuality`, `availableSubtitles`, `selectedSubtitle`, `subtitleText`, `availableAudioTracks`, `selectedAudioTrack`, `playbackSpeed`, `volume`, `isMuted`, `size`, and `error`.

### Playback Controls

```dart
await controller.play();
await controller.pause();
await controller.seekTo(const Duration(minutes: 1));
await controller.seekBy(const Duration(seconds: 15));
await controller.setPlaybackSpeed(1.25);
await controller.setVolume(0.8);
await controller.setMuted(true);
await controller.retry();
```

`seekBy` is clamped to the `0..duration` range.

### Optional Gesture Layer

`M3u8Player` does not enable gestures by default. Wrap it with `M3u8PlayerGestureControls` when the playback area should handle gestures:

```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: M3u8PlayerGestureControls(
    controller: controller,
    child: M3u8Player(controller: controller),
  ),
)
```

Built-in gestures:

- Vertical drags on the left adjust screen brightness. Android adjusts the current Activity window brightness, and iOS adjusts `UIScreen.main.brightness`.
- Vertical drags on the right adjust the current player volume, equivalent to `controller.setVolume(...)`.
- Horizontal drags preview the target position and call `controller.seekTo(...)` on release.

If your app already owns playback gestures, skip this wrapper. You can also disable all or individual behaviors through config:

```dart
M3u8PlayerGestureControls(
  controller: controller,
  config: const M3u8GestureControlsConfig(
    brightnessEnabled: true,
    volumeEnabled: true,
    seekEnabled: true,
    brightnessOverlayEnabled: true,
  ),
  child: M3u8Player(controller: controller),
)
```

`brightnessOverlayEnabled` is a dimming fallback. It keeps visible brightness feedback in simulators or environments where the system brightness API is not visually obvious.

### Switch Sources

Use `setSource(...)` for playlists, feeds, or episodes:

```dart
await controller.setSource(
  const M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
);
```

Switching source releases the old native player and cancels the old source's player-owned active prefetch. Data already written to disk can still be reused later.

### Play MP4/MOV

MP4/MOV sources are detected by extension with the default `sourceType: M3u8SourceType.auto`. If the URL has no standard extension, pass the source type explicitly:

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/video.mp4',
    sourceType: M3u8SourceType.progressive,
  ),
  autoPlay: true,
);
```

### Headers And Cache Keys

If your video endpoint needs headers:

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/index.m3u8',
    videoHeaders: {'Authorization': 'Bearer token'},
  ),
);
```

Default cache keys include URL and headers to avoid unsafe reuse across users, auth states, or regions. If short-lived signed URLs point to the same immutable video, pass a stable business key. Do not put sensitive user data into `cacheKey`.

```dart
const source = M3u8Source(
  videoUrl: 'https://example.com/index.m3u8?token=short-lived',
  cacheKey: 'course-123-lesson-4',
);
```

### Subtitles And Audio Tracks

Pass external WebVTT subtitles during initialization or source switching:

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  subtitles: const [
    M3u8SubtitleTrack(
      id: 'en',
      label: 'English',
      language: 'en',
      url: 'https://example.com/subtitles/en.vtt',
      mimeType: 'text/vtt',
    ),
  ],
  selectedSubtitleId: 'en',
);

await controller.setSubtitle('en');
await controller.clearSubtitle();
```

HLS audio tracks are exposed through `value.availableAudioTracks`:

```dart
await controller.setAudioTrack('en');
await controller.clearAudioTrack();
```

If video and audio are separate HLS streams, pass `audioUrl`. On iOS, external subtitles are exposed for HLS sources only; progressive MP4/MOV does not expose external subtitle tracks yet.

### Quality Selection

```dart
final qualities = controller.value.availableQualities;

await controller.setQuality(M3u8Quality.auto);

if (qualities.isNotEmpty) {
  await controller.setQuality(qualities.first);
}
```

Android constrains playback quality through ExoPlayer track selection. iOS HLS playback stays on direct `AVPlayer`; manual quality is best-effort and the final rendition is still chosen by AVPlayer ABR.

### Standalone Precache

Use `M3u8PlayerCache.precache(...)` to download outside the active playback flow:

```dart
final source = const M3u8Source(
  videoUrl: 'https://example.com/index.m3u8',
);

final taskId = await M3u8PlayerCache.precache(source);

final subscription = M3u8PlayerCache.events().listen((event) {
  if (event.taskId != taskId) {
    return;
  }

  final progress = event.bytesTotal <= 0
      ? event.byteProgress
      : event.bytesCached / event.bytesTotal;

  debugPrint(
    'status=${event.status}, progress=${(progress * 100).toStringAsFixed(1)}%',
  );
});

await M3u8PlayerCache.cancelPrecache(taskId);
await subscription.cancel();
```

Common cache APIs:

```dart
await M3u8PlayerCache.configure(
  maxSizeBytes: 1024 * 1024 * 1024,
  maxConcurrentPrecacheTasks: 2,
);

final info = await M3u8PlayerCache.info();
final tasks = await M3u8PlayerCache.tasks();
final sourceInfo = await M3u8PlayerCache.sourceInfo(source);

await M3u8PlayerCache.pausePrecache(taskId);
await M3u8PlayerCache.resumePrecache(taskId);
await M3u8PlayerCache.cancelPrecache(taskId);
await M3u8PlayerCache.clearSource(source);
```

Changing cache capacity and clearing all cache require no active native player or standalone download task. Changing only `maxConcurrentPrecacheTasks` is allowed at runtime.

### QoE Snapshots

```dart
controller.startQoeSampling(interval: const Duration(seconds: 5));

final subscription = controller.qoeSnapshots.listen((snapshot) {
  debugPrint(snapshot.toMap().toString());
});
```

`M3u8QoeSnapshot` includes playback position, buffer position, disk cache position, startup time, rebuffer totals and deltas, dropped-frame delta, recovery delta, quality-switch delta, current bitrate, observed bandwidth, selected quality, and playback speed.

### Current Limitations

- iOS and Android only.
- Network HLS/m3u8 VOD and progressive MP4/MOV are supported. DASH, SmoothStreaming, RTSP, FLV, and local files are not supported.
- MP4/MOV supports standalone full-file downloads and cache reuse after completion, but not quality selection.
- Android progressive can attach external subtitles. iOS progressive does not expose external subtitles yet.
- iOS HLS playback is handled by AVFoundation direct `AVPlayer`; manual HLS quality is best-effort.
- iOS HLS disk prefetch only commits to common VOD playlists. Live/event playlists, `#EXT-X-BYTERANGE`, I-frame-only playlists, complex encryption, and DRM playlists report an `unsupported_hls_playlist` cache error without failing playback.
- Native task queues are not restored after app restart. If your app needs a persistent download list, use the example app as a reference.

### Example App

The repository's `example` includes playback, pause, seek, playlist switching, quality, subtitles, audio tracks, standalone precache, download list, and QoE panels.

```sh
cd example
flutter run
```

### Local Verification

```sh
flutter analyze
flutter test
cd example && flutter test
```

For native changes, also run:

```sh
cd example/android && ./gradlew testDebugUnitTest
cd ../.. && cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
```
