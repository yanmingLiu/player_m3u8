# player_m3u8

[中文](#中文) | [English](#english)

## 中文

`player_m3u8` 是一个面向 iOS 和 Android 的 Flutter HLS/m3u8 播放插件。插件使用 Flutter `Texture` 渲染视频画面，Android 基于 Media3 ExoPlayer，iOS 基于 AVFoundation。

它适合需要直接播放网络 HLS/m3u8 VOD、展示播放进度/缓冲进度/磁盘预取进度，并支持播放列表切换的 Flutter 应用。

### 功能

- 网络 HLS/m3u8 播放。
- iOS 和 Android 原生解码与 Texture 渲染。
- 播放、暂停、seek、dispose。
- 播放列表切换：`setSource(...)`。
- 播放状态、进度、时长、播放器缓冲、磁盘缓存、视频尺寸、错误事件。
- 有界播放器内存缓冲，避免用超大 forward buffer 导致 OOM。
- 当前视频磁盘预取：播放暂停时仍可继续缓存，切换视频时停止旧视频主动缓存。

### 平台实现

| 平台 | 播放内核 | 渲染 | 缓存策略 |
| --- | --- | --- | --- |
| Android | Media3 ExoPlayer + HLS | Flutter Texture / SurfaceProducer | 播放和预取共用 Media3 `SimpleCache` |
| iOS | AVPlayer + AVPlayerItemVideoOutput | FlutterTexture | `URLSessionDownloadTask` 分片落盘并上报进度 |

### 安装

发布到 pub.dev 后：

```sh
flutter pub add player_m3u8
```

当前如果使用 Git 依赖：

```yaml
dependencies:
  player_m3u8:
    git:
      url: git@github.com:yanmingLiu/player_m3u8.git
      ref: main
```

### 基础用法

```dart
import 'package:player_m3u8/player_m3u8.dart';

final controller = M3u8PlayerController();

await controller.initialize(
  'https://example.com/index.m3u8',
  headers: const {'User-Agent': 'MyApp'},
  autoPlay: true,
);

M3u8Player(controller: controller);
```

在 widget 销毁时释放：

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### 播放列表切换

同一个 controller 可以切换播放源：

```dart
await controller.setSource(nextUrl, autoPlay: true);
```

切换行为：

- 旧 native player 会被释放。
- 旧 source 的主动磁盘预取任务会停止。
- 旧 source 已经写入磁盘的数据会保留，后续切回时可继续复用。
- 新 source 会创建新的 native player，并按 `autoPlay` 决定是否自动播放。

因此列表场景中不会出现多个视频同时后台下载的情况；只有当前 source 会继续播放和主动预取。

### 状态监听

`M3u8PlayerController` 是 `ValueNotifier<M3u8PlayerValue>`：

```dart
ValueListenableBuilder<M3u8PlayerValue>(
  valueListenable: controller,
  builder: (context, value, child) {
    return Text(
      'position=${value.position}, '
      'buffered=${value.bufferedPosition}, '
      'disk=${value.diskCachePosition}',
    );
  },
);
```

常用字段：

- `isInitialized`
- `isPlaying`
- `isBuffering`
- `isCompleted`
- `position`
- `duration`
- `bufferedPosition`
- `diskCachePosition`
- `isDiskCacheComplete`
- `size`
- `error`

### 项目架构

```text
lib/
  player_m3u8.dart                      Public exports
  player_m3u8_platform_interface.dart   Platform interface
  player_m3u8_method_channel.dart       Method/Event channel implementation
  src/
    m3u8_player_controller.dart         Controller and source switching
    m3u8_player.dart                    Texture widget
    m3u8_player_value.dart              Public playback state model
    m3u8_player_event.dart              Native event parser

android/src/main/kotlin/
  PlayerM3u8Plugin.kt                   Flutter plugin entry
  M3u8AndroidPlayer.kt                  ExoPlayer + Texture surface binding
  M3u8CacheManager.kt                   Media3 SimpleCache singleton
  M3u8DiskCachePrefetcher.kt            HLS playlist parsing and CacheWriter prefetch

ios/Classes/
  PlayerM3u8Plugin.swift                Flutter plugin entry
  M3u8IosPlayer.swift                   AVPlayer + FlutterTexture
  M3u8DiskCachePrefetcher.swift         HLS playlist parsing and URLSession prefetch

example/
  lib/main.dart                         Demo playlist UI and custom progress bar
```

### 缓存和性能设计

- Dart 层不下载、不拼接 `.ts` 分片。
- 播放器内存缓冲保持有界。
- 完整缓存思路走磁盘缓存/下载任务。
- 进度事件默认约 250ms 一次，避免高频 channel 压力。
- dispose 或 source 切换时释放 player、surface/texture、observer/timer、预取任务。
- Android 预取写入 Media3 `SimpleCache`，播放器可复用缓存数据。
- iOS 预取写入 app caches 目录并上报进度；AVPlayer 播放仍由系统网络栈管理。

### 当前限制

- 仅支持网络 HLS/m3u8 VOD。
- 暂不支持字幕、倍速、清晰度切换、后台播放、DRM。
- iOS 侧磁盘预取文件当前用于进度展示和后续复用扩展；如果要强制 AVPlayer 读取本地分片，需要增加 ResourceLoader 或本地代理。
- 磁盘缓存清理策略还未暴露为 Dart API。

### 示例播放源

example 内置多个 HLS 源用于切换测试：

- `https://prod-gg.niftyvaughanpxnew.com/movies/795bf902-1d7a-4811-af9e-239f0a232f3a-216100/index.m3u8`
- `https://prod-gg.niftyvaughanpxnew.com/movies/7b318dc9-64cb-49dd-bdc0-d28b80f6ed53-292394/index.m3u8`
- `https://prod-gg.niftyvaughanpxnew.com/movies/b6cf4a77-6fa1-4b15-b5ec-f440b923c281-198867/index.m3u8`
- `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`
- `https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8`
- `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8`

### 本地验证

```sh
flutter analyze
flutter test
cd example && flutter test
cd example/android && ./gradlew testDebugUnitTest
cd ../.. && cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
```

### 发布到 pub.dev

发布 Flutter 插件到 pub.dev 是标准化流程，建议按下面步骤执行。

1. 检查包名、描述、版本、homepage、repository、issue_tracker、topics。
2. 确认 `LICENSE`、`README.md`、`CHANGELOG.md` 存在且内容完整。
3. 更新 `CHANGELOG.md` 中当前版本说明。
4. 运行本地验证命令。
5. 运行 dry-run：

```sh
dart pub publish --dry-run
```

6. 修复 dry-run 中的所有 warning/error。
7. 确认 pub.dev 登录状态：

```sh
dart pub login
```

8. 执行发布：

```sh
dart pub publish
```

9. 发布后在 pub.dev 页面检查得分、平台识别、README 渲染、示例和仓库链接。

注意：不要在未确认版本号、仓库地址、LICENSE 和 dry-run 结果前执行真正发布。

## English

`player_m3u8` is a Flutter plugin for network HLS/m3u8 playback on iOS and Android. It renders video through Flutter `Texture`, uses Media3 ExoPlayer on Android, and uses AVFoundation on iOS.

It is designed for Flutter apps that need HLS/m3u8 VOD playback, playback/buffer/cache progress, error reporting, and playlist source switching.

### Features

- Network HLS/m3u8 playback.
- Native decoding and Flutter Texture rendering on iOS and Android.
- Play, pause, seek, and dispose.
- Playlist source switching through `setSource(...)`.
- Playback state, progress, duration, player buffer, disk cache, video size, and error events.
- Bounded in-memory player buffering to avoid OOM.
- Disk prefetch for the current source. Prefetch can continue while playback is paused and is stopped when switching away from the source.

### Platform Implementation

| Platform | Playback Engine | Rendering | Cache Strategy |
| --- | --- | --- | --- |
| Android | Media3 ExoPlayer + HLS | Flutter Texture / SurfaceProducer | Playback and prefetch share Media3 `SimpleCache` |
| iOS | AVPlayer + AVPlayerItemVideoOutput | FlutterTexture | `URLSessionDownloadTask` stores HLS resources and reports progress |

### Installation

After the package is published to pub.dev:

```sh
flutter pub add player_m3u8
```

For Git usage before pub.dev publishing:

```yaml
dependencies:
  player_m3u8:
    git:
      url: git@github.com:yanmingLiu/player_m3u8.git
      ref: main
```

### Basic Usage

```dart
import 'package:player_m3u8/player_m3u8.dart';

final controller = M3u8PlayerController();

await controller.initialize(
  'https://example.com/index.m3u8',
  headers: const {'User-Agent': 'MyApp'},
  autoPlay: true,
);

M3u8Player(controller: controller);
```

Dispose the controller with the owning widget:

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### Playlist Switching

Reuse one controller and switch the source:

```dart
await controller.setSource(nextUrl, autoPlay: true);
```

Switching behavior:

- The previous native player is released.
- The previous source's active disk prefetch task is stopped.
- Disk data already cached by the previous source remains available for reuse.
- A new native player is created for the new source and `autoPlay` controls playback start.

Only the current source continues playback and active prefetch. Previous sources do not keep downloading in the background.

### State Listening

`M3u8PlayerController` is a `ValueNotifier<M3u8PlayerValue>`:

```dart
ValueListenableBuilder<M3u8PlayerValue>(
  valueListenable: controller,
  builder: (context, value, child) {
    return Text(
      'position=${value.position}, '
      'buffered=${value.bufferedPosition}, '
      'disk=${value.diskCachePosition}',
    );
  },
);
```

Common fields:

- `isInitialized`
- `isPlaying`
- `isBuffering`
- `isCompleted`
- `position`
- `duration`
- `bufferedPosition`
- `diskCachePosition`
- `isDiskCacheComplete`
- `size`
- `error`

### Architecture

```text
lib/
  player_m3u8.dart                      Public exports
  player_m3u8_platform_interface.dart   Platform interface
  player_m3u8_method_channel.dart       Method/Event channel implementation
  src/
    m3u8_player_controller.dart         Controller and source switching
    m3u8_player.dart                    Texture widget
    m3u8_player_value.dart              Public playback state model
    m3u8_player_event.dart              Native event parser

android/src/main/kotlin/
  PlayerM3u8Plugin.kt                   Flutter plugin entry
  M3u8AndroidPlayer.kt                  ExoPlayer + Texture surface binding
  M3u8CacheManager.kt                   Media3 SimpleCache singleton
  M3u8DiskCachePrefetcher.kt            HLS playlist parsing and CacheWriter prefetch

ios/Classes/
  PlayerM3u8Plugin.swift                Flutter plugin entry
  M3u8IosPlayer.swift                   AVPlayer + FlutterTexture
  M3u8DiskCachePrefetcher.swift         HLS playlist parsing and URLSession prefetch

example/
  lib/main.dart                         Demo playlist UI and custom progress bar
```

### Cache And Performance

- Dart does not download or concatenate `.ts` segments.
- Player memory buffers are bounded.
- Full-video prefetch is handled through disk cache/download tasks.
- Progress events are throttled to about 250ms.
- dispose and source switching release native players, surfaces/textures, observers/timers, and active prefetch tasks.
- Android prefetch writes to Media3 `SimpleCache`, which ExoPlayer can reuse.
- iOS prefetch writes to the app caches directory and reports progress; AVPlayer playback still uses the system network stack.

### Current Limitations

- Network HLS/m3u8 VOD only.
- No subtitles, playback speed, quality switching, background playback, or DRM yet.
- iOS disk prefetch currently supports progress reporting and future reuse extension. To force AVPlayer to consume local segments, add ResourceLoader or a local proxy.
- Disk cache cleanup is not exposed as a Dart API yet.

### Example Sources

The example app includes multiple HLS sources for switching tests:

- `https://prod-gg.niftyvaughanpxnew.com/movies/795bf902-1d7a-4811-af9e-239f0a232f3a-216100/index.m3u8`
- `https://prod-gg.niftyvaughanpxnew.com/movies/7b318dc9-64cb-49dd-bdc0-d28b80f6ed53-292394/index.m3u8`
- `https://prod-gg.niftyvaughanpxnew.com/movies/b6cf4a77-6fa1-4b15-b5ec-f440b923c281-198867/index.m3u8`
- `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`
- `https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8`
- `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8`

### Local Verification

```sh
flutter analyze
flutter test
cd example && flutter test
cd example/android && ./gradlew testDebugUnitTest
cd ../.. && cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
```

### Publishing To pub.dev

Publishing a Flutter plugin to pub.dev is a standardized flow:

1. Check package name, description, version, homepage, repository, issue_tracker, and topics.
2. Make sure `LICENSE`, `README.md`, and `CHANGELOG.md` exist and are complete.
3. Update the current version entry in `CHANGELOG.md`.
4. Run local verification.
5. Run a dry run:

```sh
dart pub publish --dry-run
```

6. Fix all dry-run warnings and errors.
7. Confirm pub.dev authentication:

```sh
dart pub login
```

8. Publish:

```sh
dart pub publish
```

9. After publishing, check the pub.dev page for score, supported platforms, README rendering, examples, and repository links.

Do not run the real publish command until version, repository, license, and dry-run output have been reviewed.
