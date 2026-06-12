# player_m3u8

[中文](#中文) | [English](#english)

## 中文

`player_m3u8` 是一个面向 iOS 和 Android 的 Flutter HLS/m3u8 播放插件，并支持 progressive MP4/MOV 播放。插件使用 Flutter `Texture` 渲染视频画面，Android 基于 Media3 ExoPlayer，iOS 基于 AVFoundation。

它适合需要直接播放网络 HLS/m3u8 VOD 或 MP4/MOV 文件、展示播放进度/缓冲进度，并支持播放列表切换的 Flutter 应用。HLS source 额外支持磁盘预取、清晰度选择和 seek-aware 预取。

### 功能

- 网络 HLS/m3u8 播放，以及 progressive MP4/MOV 播放。
- iOS 和 Android 原生解码与 Texture 渲染。
- 播放、暂停、seek、相对快进/快退、倍速、音量/静音、错误重试、dispose。
- 播放列表切换：`setSource(...)`。
- 播放状态、进度、时长、播放器缓冲、磁盘缓存、视频尺寸、错误事件。
- 播放健康指标：首帧耗时、rebuffer 次数和总时长、丢帧数、当前码率、观测带宽、清晰度切换次数。
- HLS 清晰度列表和 Auto/手动清晰度选择；MP4/MOV 不提供清晰度选择。
- HLS 内嵌字幕和外部 WebVTT 字幕；Android progressive 也可挂外部字幕，iOS progressive 暂不暴露外部字幕。
- 播放倍速控制，支持 0.25x 到 2.0x。
- 音量和静音控制，切换 source 后保留当前音频状态。
- 连续 rebuffer 或播放错误时自动降到下一档清晰度并尝试恢复当前位置。
- 有界播放器内存缓冲，避免用超大 forward buffer 导致 OOM。
- 可配置磁盘缓存容量，并支持清理磁盘缓存。
- HLS 当前视频磁盘预取：播放暂停时仍可继续缓存，切换视频时停止旧视频主动缓存。
- HLS seek 后磁盘预取会从新的播放位置重新开始，优先缓存用户即将观看的内容。

### 平台实现

| 平台 | 播放内核 | 渲染 | 缓存策略 |
| --- | --- | --- | --- |
| Android | Media3 ExoPlayer + HLS/progressive | Flutter Texture / SurfaceProducer | HLS 播放、HLS 独立下载和 progressive 独立下载共用 Media3 `SimpleCache` |
| iOS | AVPlayer + AVPlayerItemVideoOutput | FlutterTexture | HLS 播放通过 `AVAssetResourceLoader` 复用 app caches；HLS 磁盘预取仅支持可完整结束的 VOD playlist；progressive 完整下载后复用本地缓存文件 |

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
  source: const M3u8Source(
    videoUrl: 'https://example.com/index.m3u8',
    videoHeaders: const {'User-Agent': 'MyApp'},
  ),
  autoPlay: true,
  initialPosition: const Duration(seconds: 30),
);

M3u8Player(controller: controller);
```

MP4/MOV 会在默认 `sourceType: M3u8SourceType.auto` 下按后缀自动识别；如果 URL 没有标准后缀，可以显式传入：

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/video.mp4',
    sourceType: M3u8SourceType.progressive,
  ),
  autoPlay: true,
);
```

#### 音视频分离源

如果视频和音频是分开的 HLS 流，可以通过 `audioUrl` 参数指定外部音频源：

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/video-only.m3u8',
    audioUrl: 'https://example.com/audio-only.m3u8',
    audioHeaders: {'User-Agent': 'MyAudioApp'},
  ),
  autoPlay: true,
);
```

`audioHeaders` 未设置时自动沿用 `videoHeaders`。

#### 字幕

HLS 内嵌字幕会通过 native track 信息上报；外部 WebVTT 字幕可在初始化或切换 source 时传入：

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

iOS 外部字幕当前通过 HLS `SUBTITLES` rendition 注入实现，因此只对 HLS source 暴露；progressive MP4/MOV 在 iOS 上不会上报外部字幕列表。

#### 音频轨道选择

```dart
// 查看可用音频轨道
controller.value.availableAudioTracks; // List<M3u8AudioTrack>

// 选择音频轨道
await controller.setAudioTrack('audio:en');

// 取消选择（使用默认音频）
await controller.clearAudioTrack();
```

#### 播放列表切换

```dart
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
);
```

#### 预缓存（仅 HLS）

```dart
await M3u8PlayerCache.precache(
  M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  initialPosition: Duration.zero,
);
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
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
);
```

如果要恢复历史播放进度或从推荐流跳转到指定时间，可以在创建 source 时传入初始位置：

```dart
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
  initialPosition: resumePosition,
);
```

切换行为：

- 旧 native player 会被释放。
- 旧 source 的主动磁盘预取任务会停止。
- 旧 source 已经写入磁盘的数据会保留，后续切回时可继续复用。
- 新 source 会创建新的 native player，并按 `autoPlay` 决定是否自动播放。
- 如传入 `initialPosition`，播放内核和主动磁盘预取都会优先从该位置开始。

因此列表场景中不会出现多个视频同时后台下载的情况；只有当前 source 会继续播放和主动预取。

### 磁盘缓存配置

默认磁盘缓存上限是 512 MB。可以在创建播放器前配置容量，或在没有活跃播放器时清理缓存：

```dart
await M3u8PlayerCache.configure(maxSizeBytes: 1024 * 1024 * 1024);
final cacheInfo = await M3u8PlayerCache.info();
final taskId = await M3u8PlayerCache.precache(
  M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  initialPosition: resumePosition,
  quality: controller.value.selectedQuality,
);
final cacheSubscription = M3u8PlayerCache.events().listen((event) {
  if (event.taskId == taskId) {
    // Update cache progress UI.
  }
});
await M3u8PlayerCache.cancelPrecache(taskId);
await M3u8PlayerCache.clear();
```

缓存容量配置和全量清理要求当前没有活跃 native player 或独立下载任务；只调整 `maxConcurrentPrecacheTasks` 可在运行期调用，用于播放中降低后台下载并发。查询缓存状态、source 缓存状态和独立下载任务可在播放中调用。独立下载返回 `taskId`，进度通过 `M3u8PlayerCache.events()` 上报，可按 `taskId` 过滤，并支持暂停、恢复和取消。`precache` 可传入 `priority`、`maxRetries`、`metadata` 和 HLS `quality`；`configure` 可配置 `maxConcurrentPrecacheTasks`。Android HLS 下载复用 Media3 `HlsPlaylistParser` + `CacheWriter` + `SimpleCache`，progressive MP4/MOV 通过 Media3 `CacheWriter` 写入同一 `SimpleCache`；iOS HLS 复用 AVFoundation resource loader 同一套 app caches，progressive MP4/MOV 完整下载后下次播放优先复用本地缓存文件。默认缓存 key 包含 URL 和请求 headers，避免不同 Authorization/Cookie/地区 header 的资源互相复用；如果业务确认同一视频的短期签名 URL 可共享缓存，可在 `M3u8Source.cacheKey` 传入稳定业务 key。播放器 source 切换会取消播放器内部预取；业务自己发起的独立下载任务应按业务生命周期主动取消。

播放器内部磁盘缓存和独立下载任务是两条概念：内部缓存服务当前播放、seek 和短期复用，不进入下载列表；独立下载任务由业务调用 `precache` 创建，可展示任务状态、速度、字节、segment、错误，并支持暂停、恢复和取消。

```dart
final source = M3u8Source(
  videoUrl: 'https://example.com/video.mp4?token=short-lived',
  sourceType: M3u8SourceType.progressive,
  cacheKey: 'video-123',
);

final taskId = await M3u8PlayerCache.precache(
  source,
  priority: 10,
  maxRetries: 3,
  metadata: {'title': 'Episode 1'},
);
final tasks = await M3u8PlayerCache.tasks();
final sourceInfo = await M3u8PlayerCache.sourceInfo(source);
await M3u8PlayerCache.pausePrecache(taskId);
await M3u8PlayerCache.resumePrecache(taskId);
await M3u8PlayerCache.clearSource(source);
```

### 清晰度选择

播放器会在状态中暴露 HLS master playlist 中的可用清晰度；MP4/MOV 的 `availableQualities` 为空，调用 `setQuality` 会返回 `unsupported_source_type`：

```dart
final qualities = controller.value.availableQualities;
await controller.setQuality(M3u8Quality.auto);
await controller.setQuality(qualities.first);
```

`M3u8Quality.auto` 使用平台播放器的自适应选择。手动清晰度会对 Android ExoPlayer 施加 track selector 约束；iOS 会在 `AVAssetResourceLoader` 返回给 AVPlayer 的 master playlist 中过滤到目标 variant。连续 rebuffer 或播放错误时，如果存在更低档 variant，播放器会自动降到下一档并尝试恢复到原播放位置；`recoveryCount` 和 `lastRecoveryReason` 可用于 UI 提示或埋点。

### 播放倍速

初始化、切换 source 或播放中都可以设置倍速：

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  playbackSpeed: 1.25,
);
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  playbackSpeed: 1.5,
);
await controller.setPlaybackSpeed(2.0);
```

倍速范围是 0.25x 到 2.0x。Android 使用 ExoPlayer `PlaybackParameters`，iOS 使用 AVPlayer `rate`；切换清晰度或自动恢复后会保持当前倍速。

### 音量和静音

初始化、切换 source 或播放中都可以设置音频状态：

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  volume: 0.8,
  isMuted: false,
);
await controller.setVolume(0.5);
await controller.setMuted(true);
```

`volume` 范围是 0.0 到 1.0；`isMuted` 不会覆盖保存的音量值，取消静音后会恢复到当前 `volume`。

### 快退和快进

可以用绝对位置 seek，也可以用相对偏移快退/快进：

```dart
await controller.seekTo(const Duration(minutes: 3));
await controller.seekBy(const Duration(seconds: -10));
await controller.seekBy(const Duration(seconds: 10));
```

`seekBy` 会自动裁剪到 `0..duration` 范围内，底层仍调用平台 `seekTo`，因此主动磁盘预取会沿用 seek-aware 策略从新目标位置重启。

### 错误重试

播放错误后可以直接重建当前 source：

```dart
await controller.retry(autoPlay: true);
```

`retry` 会释放旧 native player，按当前播放位置重新创建 source，并保留恢复策略、倍速、音量和静音状态。

错误码、触发条件和建议处理动作见 `ERROR_CODES.md`。业务上建议至少区分 `unsupported_source_type`、`unsupported_hls_playlist`、`unknown_player`、`active_players`、`active_cache_tasks` 和平台播放错误。

### 自动恢复策略

默认策略是启用自动恢复、连续 3 次 rebuffer 后触发降档、两次恢复至少间隔 10 秒。可以在初始化、切换 source 或播放中调整：

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  recoveryPolicy: const M3u8RecoveryPolicy(
    rebufferThreshold: 2,
    minimumRecoveryInterval: Duration(seconds: 6),
    minimumAutoQualityHeight: 480,
  ),
);

await controller.setRecoveryPolicy(M3u8RecoveryPolicy.disabled);
```

`minimumAutoQualityHeight` 用于限制自动恢复时最低降到哪一档；例如设为 480 时，自动降级不会主动选择低于 480p 的 variant。

### QoE 快照

业务层可以订阅周期性 QoE 快照，用于真实设备压测或埋点上报：

```dart
final subscription = controller.qoeSnapshots.listen((snapshot) {
  analytics.logEvent('player_qoe', snapshot.toMap());
});

controller.startQoeSampling(interval: const Duration(seconds: 5));
```

`M3u8QoeSnapshot` 会输出窗口起止时间、当前播放位置、缓冲/磁盘缓存位置、首帧耗时、rebuffer 次数和窗口增量、rebuffer 总时长和窗口增量、丢帧增量、恢复增量、清晰度切换增量、当前码率、观测带宽、当前清晰度和播放倍速。

播放状态中的 `diagnostics` 适合随错误和 QoE 一起上报：

```dart
controller.addListener(() {
  final value = controller.value;
  if (value.hasError) {
    analytics.logEvent('player_error', {
      'code': value.error!.code,
      'message': value.error!.message,
      'sessionId': value.diagnostics['sessionId'],
      'sourceId': value.diagnostics['sourceId'],
      'sourceType': value.diagnostics['sourceType'],
      'positionMs': value.diagnostics['positionMs'],
      'rebufferCount': value.rebufferCount,
      'startupTimeMs': value.startupTime.inMilliseconds,
    });
  }
});
```

### 状态监听

`M3u8PlayerController` 是 `ValueNotifier<M3u8PlayerValue>`：

```dart
ValueListenableBuilder<M3u8PlayerValue>(
  valueListenable: controller,
  builder: (context, value, child) {
    return Text(
      'position=${value.position}, '
      'buffered=${value.bufferedPosition}, '
      'diskStart=${value.diskCacheStartPosition}, '
      'disk=${value.diskCachePosition}, '
      'diskPercent=${value.diskCachePercent}',
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
- `diskCacheStartPosition`
- `diskCachePosition`
- `diskCachePercent`
- `isDiskCacheComplete`
- `startupTime`
- `rebufferCount`
- `rebufferDuration`
- `droppedFrames`
- `videoBitrate`
- `observedBitrate`
- `qualitySwitchCount`
- `availableQualities`
- `selectedQuality`
- `recoveryCount`
- `lastRecoveryReason`
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
  M3u8DiskCachePrefetcher.kt            Media3 playlist parsing and seek-aware disk prefetch

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
- Android 播放器内部 HLS 预取使用 Media3 `HlsPlaylistParser` 解析 HLS，并通过 Media3 `CacheWriter` 写入 `SimpleCache`；独立 HLS/progressive 下载也写入同一个 `SimpleCache`，播放器可直接复用。
- iOS HLS 播放通过 `AVAssetResourceLoader` 读取自定义 scheme，playlist、key、map、segment 和外部字幕请求会优先命中 app caches；progressive 独立下载完成后，新建播放器会优先使用本地缓存文件。
- 磁盘缓存 key 会包含 URL 和请求 headers，避免同 URL 在不同 Authorization/Cookie/地区 header 下复用错误缓存。
- `M3u8PlayerCache.precache` 可创建独立 HLS/MP4/MOV 下载任务，并通过独立 cache event channel 上报进度、完成、取消或错误；传入 `quality` 后会优先下载最接近该档位的 HLS variant。
- 播放器内部预取不是下载任务，不进入 `tasks()` 和下载列表；下载列表只展示业务主动创建的独立任务。
- 播放中建议降低 `maxConcurrentPrecacheTasks`，避免下载任务与播放器抢占网络和 IO；example 会对同一 source 去重，并在播放活跃时把独立下载并发降为 1。
- HLS 播放器内部主动预取会跟随手动清晰度、自动降级恢复和 seek 位置重启，不再固定优先最高码率 variant。
- Android 通过 ExoPlayer track/analytics 上报首帧、rebuffer、丢帧、当前码率和带宽估计；iOS 通过 AVPlayer access log 和视频轨道信息上报对应指标。rebuffer 总时长和清晰度切换次数可用于真实设备 QoE 统计。
- 播放事件会携带 `diagnostics` 上下文，包括平台、session/source 标识、source type、播放位置、缓冲位置和缓存 key 状态，用于线上错误聚合与 QoE 归因；不要把业务敏感数据写入 `cacheKey` 或 URL 查询参数后直接上报。
- Android 手动清晰度通过 `DefaultTrackSelector` 约束最高视频尺寸和码率；iOS 手动清晰度通过 ResourceLoader 过滤 HLS master variants。
- 连续 rebuffer 或播放错误触发自动降级恢复，保留当前位置；没有更低档可降时才向 Dart 上报播放错误。
- seek 后会取消当前主动预取，并从目标时间对应的分片开始向后预取；已写入磁盘的数据保留复用。

### 当前限制

- 支持网络 HLS/m3u8 VOD 和 progressive MP4/MOV；不支持 DASH、SmoothStreaming、RTSP、FLV 或本地文件。
- MP4/MOV 支持独立完整下载和完成后缓存复用，但不支持清晰度选择。
- 字幕支持以 WebVTT/HLS text track 为主；Android progressive 可挂外部字幕，iOS progressive 暂不支持外部字幕。
- 暂不支持 DRM/FairPlay/Widevine、后台播放、锁屏控制、AirPlay、Cast、Picture in Picture、低延迟直播。
- 当前已支持手动清晰度约束，但尚未暴露自定义自动码率策略。
- iOS HLS 播放仍交给 AVFoundation 尝试；iOS HLS 磁盘预取只承诺常见 VOD playlist。live/event playlist、`#EXT-X-BYTERANGE`、I-frame-only playlist、复杂加密或 DRM playlist 会返回 `unsupported_hls_playlist` 缓存错误，播放链路不因此失败。
- 磁盘缓存容量配置和清理必须在没有活跃播放器和独立下载任务时调用；下载并发数可运行期调整，但不会强制取消已经运行中的任务。
- 原生层不承诺 app 重启后恢复未完成下载队列；example 会持久化下载记录，并在启动后通过 `sourceInfo` 恢复已完成缓存记录。
- 商用试点前请按 `COMMERCIAL_ACCEPTANCE.md` 执行自动化和真机验收。

### 示例工程

example 默认使用中文界面，顶部按钮可在中文和英文之间切换。示例内置多个公开 HLS 和 MP4 测试源，用于切换播放、清晰度、缓存、seek 后预取，以及 progressive 播放验证：

example 的 More sheet 提供下载列表入口；下载列表使用 `metadata.title` 显示资源名称，完成的任务可点击切换到对应 source 并复用本地缓存播放。QoE 面板上方的缓存/下载指标看板会分开展示播放器内部缓存和独立下载任务，下载当前源时会复用已有任务或已完成缓存记录，避免同源重复下载。

| 名称 | 地址 |
| --- | --- |
| Apple BipBop | `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8` |
| Google Shaka Angel One | `https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8` |
| Google Shaka Big Buck Bunny | `https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8` |
| Mux Tears of Steel | `https://test-streams.mux.dev/tos_ismc/main.m3u8` |
| Akamai HLS Test | `https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8` |
| AWS CloudFront Sintel | `https://d2zihajmogu5jn.cloudfront.net/sintel/master.m3u8` |
| MP4 Video.js Oceans | `https://vjs.zencdn.net/v/oceans.mp4` |
| MP4 W3C Sintel Trailer | `https://media.w3.org/2010/05/sintel/trailer.mp4` |
| MP4 W3Schools Big Buck Bunny | `https://www.w3schools.com/html/mov_bbb.mp4` |
| MP4 MDN Flower | `https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4` |

example 页面还包含播放控制、播放列表切换、独立磁盘预取控制、播放健康指标和 QoE 快照面板，可在真机调试时观察最近采样窗口的 rebuffer ratio、丢帧增量、恢复增量、清晰度切换增量，并复制最新快照 JSON。

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

`player_m3u8` is a Flutter plugin for network HLS/m3u8 playback on iOS and Android, with progressive MP4/MOV playback support. It renders video through Flutter `Texture`, uses Media3 ExoPlayer on Android, and uses AVFoundation on iOS.

It is designed for Flutter apps that need HLS/m3u8 VOD or MP4/MOV playback, playback/buffer progress, error reporting, and playlist source switching. HLS sources also support disk prefetch, quality selection, and seek-aware prefetch.

### Features

- Network HLS/m3u8 playback plus progressive MP4/MOV playback.
- Native decoding and Flutter Texture rendering on iOS and Android.
- Play, pause, seek, relative skip, playback speed, volume/mute, error retry, and dispose.
- Playlist source switching through `setSource(...)`.
- Playback state, progress, duration, player buffer, disk cache, video size, and error events.
- Playback health metrics: startup time, rebuffer count and duration, dropped frames, current video bitrate, observed bitrate, and quality switch count.
- HLS quality list plus Auto/manual quality selection. MP4/MOV sources do not expose quality selection.
- Built-in HLS subtitles and external WebVTT subtitles. Android progressive sources can attach external subtitles; iOS progressive sources do not expose external subtitles yet.
- Playback speed control from 0.25x to 2.0x.
- Volume and mute controls that survive source switching.
- Automatic lower-quality recovery after repeated rebuffering or playback errors.
- Bounded in-memory player buffering to avoid OOM.
- Configurable disk cache size and disk cache clearing.
- HLS disk prefetch for the current source. Prefetch can continue while playback is paused and is stopped when switching away from the source.
- After HLS seek, disk prefetch restarts from the new playback position and prioritizes the content the user is about to watch.

### Platform Implementation

| Platform | Playback Engine | Rendering | Cache Strategy |
| --- | --- | --- | --- |
| Android | Media3 ExoPlayer + HLS/progressive | Flutter Texture / SurfaceProducer | HLS playback, HLS standalone downloads, and progressive standalone downloads share Media3 `SimpleCache` |
| iOS | AVPlayer + AVPlayerItemVideoOutput | FlutterTexture | HLS playback reuses app caches through `AVAssetResourceLoader`; HLS disk prefetch supports complete VOD playlists only; progressive playback reuses fully downloaded local cache files |

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
  source: const M3u8Source(
    videoUrl: 'https://example.com/index.m3u8',
    videoHeaders: {'User-Agent': 'MyApp'},
  ),
  autoPlay: true,
  initialPosition: const Duration(seconds: 30),
);

M3u8Player(controller: controller);
```

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

Dispose the controller with the owning widget:

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### Separate Audio Sources

If video and audio are separate HLS streams, pass `audioUrl` on the source:

```dart
await controller.initialize(
  source: const M3u8Source(
    videoUrl: 'https://example.com/video-only.m3u8',
    audioUrl: 'https://example.com/audio-only.m3u8',
    audioHeaders: {'User-Agent': 'MyAudioApp'},
  ),
  autoPlay: true,
);
```

When `audioHeaders` is omitted, the player reuses `videoHeaders`.

### Subtitles

Built-in HLS text tracks are reported by the native player. External WebVTT subtitles can be attached during initialization or source switching:

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

iOS external subtitles are injected as HLS `SUBTITLES` renditions, so they are exposed only for HLS sources. Android progressive sources can attach external subtitles.

### Playlist Switching

Reuse one controller and switch the source:

```dart
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
);
```

To resume watch history or jump into a feed item at a specific timestamp, pass an initial position when creating the source:

```dart
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  autoPlay: true,
  initialPosition: resumePosition,
);
```

Switching behavior:

- The previous native player is released.
- The previous source's active disk prefetch task is stopped.
- Disk data already cached by the previous source remains available for reuse.
- A new native player is created for the new source and `autoPlay` controls playback start.
- When `initialPosition` is supplied, playback and active disk prefetch both start from that position.

Only the current source continues playback and active prefetch. Previous sources do not keep downloading in the background.

### Disk Cache Configuration

The default disk cache limit is 512 MB. Configure it before creating players, or clear the cache when no players are active:

```dart
await M3u8PlayerCache.configure(maxSizeBytes: 1024 * 1024 * 1024);
final cacheInfo = await M3u8PlayerCache.info();
final taskId = await M3u8PlayerCache.precache(
  M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  initialPosition: resumePosition,
  quality: controller.value.selectedQuality,
);
final cacheSubscription = M3u8PlayerCache.events().listen((event) {
  if (event.taskId == taskId) {
    // Update cache progress UI.
  }
});
await M3u8PlayerCache.cancelPrecache(taskId);
await M3u8PlayerCache.clear();
```

Changing cache capacity and clearing all cache require no active native players or standalone download tasks. Changing only `maxConcurrentPrecacheTasks` can be done at runtime, which lets apps reduce background download concurrency during playback. Cache info, source cache info, and standalone download tasks can run while playback is active. Standalone downloads return a `taskId`, emit progress through `M3u8PlayerCache.events()`, and support pause, resume, and cancel by `taskId`. `precache` accepts `priority`, `maxRetries`, `metadata`, and HLS `quality`; `configure` accepts `maxConcurrentPrecacheTasks`. Android HLS downloads reuse Media3 `HlsPlaylistParser`, `CacheWriter`, and `SimpleCache`, while progressive MP4/MOV uses Media3 `CacheWriter` into the same `SimpleCache`. iOS HLS reuses the AVFoundation resource loader app cache path, while progressive MP4/MOV reuses a fully cached local file on the next playback. Default cache keys include URL and request headers to avoid reusing data across different Authorization/Cookie/region headers. If your business URL is short-lived but identifies the same immutable video, pass a stable `M3u8Source.cacheKey`. Player source switching cancels player-owned prefetch; app-owned standalone download tasks should be cancelled according to app lifecycle.

Player-owned disk cache and standalone downloads are separate concepts. Player-owned cache serves current playback, seek, and short-term reuse, and does not appear in the download list. Standalone downloads are created by app calls to `precache`; they expose status, speed, bytes, segment progress, errors, and pause/resume/cancel controls.

```dart
final source = M3u8Source(
  videoUrl: 'https://example.com/video.mp4?token=short-lived',
  sourceType: M3u8SourceType.progressive,
  cacheKey: 'video-123',
);

final taskId = await M3u8PlayerCache.precache(
  source,
  priority: 10,
  maxRetries: 3,
  metadata: {'title': 'Episode 1'},
);
final tasks = await M3u8PlayerCache.tasks();
final sourceInfo = await M3u8PlayerCache.sourceInfo(source);
await M3u8PlayerCache.pausePrecache(taskId);
await M3u8PlayerCache.resumePrecache(taskId);
await M3u8PlayerCache.clearSource(source);
```

### Quality Selection

The player exposes variants from the HLS master playlist. MP4/MOV `availableQualities` is empty, and `setQuality` returns `unsupported_source_type`:

```dart
final qualities = controller.value.availableQualities;
await controller.setQuality(M3u8Quality.auto);
await controller.setQuality(qualities.first);
```

`M3u8Quality.auto` uses the platform player's adaptive selection. Manual quality constrains Android ExoPlayer through the track selector; iOS filters the master playlist returned by `AVAssetResourceLoader` to the target variant. After repeated rebuffering or playback errors, the player automatically steps down to a lower variant when one is available and tries to resume at the previous position. Use `recoveryCount` and `lastRecoveryReason` for UI hints or analytics.

### Playback Speed

Set playback speed during initialization, source switching, or playback:

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  playbackSpeed: 1.25,
);
await controller.setSource(
  M3u8Source(videoUrl: 'https://example.com/next.m3u8'),
  playbackSpeed: 1.5,
);
await controller.setPlaybackSpeed(2.0);
```

The supported range is 0.25x to 2.0x. Android uses ExoPlayer `PlaybackParameters`; iOS uses AVPlayer `rate`. Quality switching and automatic recovery preserve the current speed.

### Volume And Mute

Set audio state during initialization, source switching, or playback:

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  volume: 0.8,
  isMuted: false,
);
await controller.setVolume(0.5);
await controller.setMuted(true);
```

`volume` ranges from 0.0 to 1.0. `isMuted` does not overwrite the stored volume, so unmuting restores the current `volume`.

### Skip Back And Forward

Use absolute seeking or relative skip:

```dart
await controller.seekTo(const Duration(minutes: 3));
await controller.seekBy(const Duration(seconds: -10));
await controller.seekBy(const Duration(seconds: 10));
```

`seekBy` clamps to the `0..duration` range and still calls platform `seekTo`, so active disk prefetch keeps using the seek-aware restart policy.

### Error Retry

Recreate the current source after a playback error:

```dart
await controller.retry(autoPlay: true);
```

`retry` releases the previous native player, recreates the source at the current playback position, and keeps the recovery policy, playback speed, volume, and mute state.

See `ERROR_CODES.md` for error codes, triggers, and suggested handling. Product code should at least distinguish `unsupported_source_type`, `unsupported_hls_playlist`, `unknown_player`, `active_players`, `active_cache_tasks`, and platform playback errors.

### Recovery Policy

The default policy enables automatic recovery, steps down after 3 rebuffers, and keeps at least 10 seconds between recovery attempts. Configure it during initialization, source switching, or playback:

```dart
await controller.initialize(
  source: const M3u8Source(videoUrl: 'https://example.com/index.m3u8'),
  recoveryPolicy: const M3u8RecoveryPolicy(
    rebufferThreshold: 2,
    minimumRecoveryInterval: Duration(seconds: 6),
    minimumAutoQualityHeight: 480,
  ),
);

await controller.setRecoveryPolicy(M3u8RecoveryPolicy.disabled);
```

`minimumAutoQualityHeight` limits how far automatic recovery can step down. For example, `480` prevents automatic recovery from selecting variants below 480p.

### QoE Snapshots

Apps can subscribe to periodic QoE snapshots for real-device profiling or analytics:

```dart
final subscription = controller.qoeSnapshots.listen((snapshot) {
  analytics.logEvent('player_qoe', snapshot.toMap());
});

controller.startQoeSampling(interval: const Duration(seconds: 5));
```

`M3u8QoeSnapshot` includes the window start/end time, playback position, buffer/disk-cache position, startup time, rebuffer totals and window deltas, rebuffer duration totals and window deltas, dropped-frame deltas, recovery deltas, quality-switch deltas, current bitrate, observed bitrate, selected quality, and playback speed.

The current value's `diagnostics` map is designed to be sent with errors and QoE events:

```dart
controller.addListener(() {
  final value = controller.value;
  if (value.hasError) {
    analytics.logEvent('player_error', {
      'code': value.error!.code,
      'message': value.error!.message,
      'sessionId': value.diagnostics['sessionId'],
      'sourceId': value.diagnostics['sourceId'],
      'sourceType': value.diagnostics['sourceType'],
      'positionMs': value.diagnostics['positionMs'],
      'rebufferCount': value.rebufferCount,
      'startupTimeMs': value.startupTime.inMilliseconds,
    });
  }
});
```

### State Listening

`M3u8PlayerController` is a `ValueNotifier<M3u8PlayerValue>`:

```dart
ValueListenableBuilder<M3u8PlayerValue>(
  valueListenable: controller,
  builder: (context, value, child) {
    return Text(
      'position=${value.position}, '
      'buffered=${value.bufferedPosition}, '
      'diskStart=${value.diskCacheStartPosition}, '
      'disk=${value.diskCachePosition}, '
      'diskPercent=${value.diskCachePercent}',
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
- `diskCacheStartPosition`
- `diskCachePosition`
- `diskCachePercent`
- `isDiskCacheComplete`
- `startupTime`
- `rebufferCount`
- `rebufferDuration`
- `droppedFrames`
- `videoBitrate`
- `observedBitrate`
- `qualitySwitchCount`
- `availableQualities`
- `selectedQuality`
- `recoveryCount`
- `lastRecoveryReason`
- `size`
- `error`

### Architecture

```text
lib/
  player_m3u8.dart                      Public exports
  player_m3u8_platform_interface.dart   Platform interface
  player_m3u8_method_channel.dart       Method/Event channel implementation
  src/
    m3u8_player_cache.dart              Disk cache configuration and clearing
    m3u8_player_controller.dart         Controller and source switching
    m3u8_player.dart                    Texture widget
    m3u8_player_value.dart              Public playback state model
    m3u8_player_event.dart              Native event parser

android/src/main/kotlin/
  PlayerM3u8Plugin.kt                   Flutter plugin entry
  M3u8AndroidPlayer.kt                  ExoPlayer + Texture surface binding
  M3u8CacheManager.kt                   Media3 SimpleCache singleton
  M3u8DiskCachePrefetcher.kt            Media3 playlist parsing and seek-aware disk prefetch

ios/Classes/
  PlayerM3u8Plugin.swift                Flutter plugin entry
  M3u8IosPlayer.swift                   AVPlayer + FlutterTexture
  M3u8ResourceLoader.swift              AVAssetResourceLoader cache bridge
  M3u8IosCacheManager.swift             iOS app caches storage and LRU trim
  M3u8DiskCachePrefetcher.swift         HLS playlist parsing and seek-aware disk prefetch

example/
  lib/main.dart                         Demo playlist UI and custom progress bar
```

### Cache And Performance

- Dart does not download or concatenate `.ts` segments.
- Player memory buffers are bounded.
- Full-video prefetch is handled through disk cache/download tasks.
- Progress events are throttled to about 250ms.
- dispose and source switching release native players, surfaces/textures, observers/timers, and active prefetch tasks.
- Android player-owned HLS prefetch uses Media3 `HlsPlaylistParser` for HLS parsing and Media3 `CacheWriter` to write into `SimpleCache`. Standalone HLS/progressive downloads write into the same `SimpleCache`, which ExoPlayer can reuse directly.
- iOS HLS playback uses `AVAssetResourceLoader` with a custom scheme. Playlist, key, map, segment, and external subtitle requests read from app caches first; progressive playback uses a local cache file after a standalone download completes.
- Disk cache keys include URL and request headers, so resources with different Authorization, Cookie, or region headers do not share stale cached data.
- `M3u8PlayerCache.precache` creates standalone HLS/MP4/MOV download tasks with cache events for progress, completion, cancellation, and errors. Passing `quality` prioritizes the closest HLS variant for that rendition.
- Player-owned prefetch is not a download task and does not appear in `tasks()` or the download list. The download list only shows app-owned standalone tasks.
- During playback, reduce `maxConcurrentPrecacheTasks` to avoid network and IO contention. The example de-duplicates same-source downloads and lowers standalone download concurrency to 1 while playback is active.
- HLS player-owned active prefetch follows manual quality, automatic recovery downshifts, and seek restarts instead of always prioritizing the highest bitrate variant.
- Android reports startup, rebuffer, dropped-frame, bitrate, and bandwidth metrics through ExoPlayer tracks/analytics. iOS reports the same metric class through AVPlayer access logs and video track data. Total rebuffer duration and quality switch count are available for real-device QoE analytics.
- Playback events include `diagnostics` context with platform, session/source identifiers, source type, playback position, buffered position, and cache-key state for production error aggregation and QoE attribution. Do not put sensitive business data in `cacheKey` or URL query parameters if those values are forwarded to analytics.
- Android manual quality constrains maximum video size and bitrate through `DefaultTrackSelector`; iOS manual quality filters HLS master variants through ResourceLoader.
- Repeated rebuffering or playback errors trigger automatic lower-quality recovery and preserve the playback position. Playback errors are reported to Dart only when no lower variant is available.
- After seek, active prefetch is canceled and restarted from the segment that matches the target time. Already cached data remains reusable.

### Current Limitations

- Network HLS/m3u8 VOD and progressive MP4/MOV are supported. DASH, SmoothStreaming, RTSP, FLV, and local files are not supported.
- MP4/MOV supports standalone full-file downloads and cache reuse after completion, but not quality selection.
- Subtitle support targets WebVTT and HLS text tracks. Android progressive sources can attach external subtitles; iOS progressive external subtitles are not exposed yet.
- DRM/FairPlay/Widevine, background playback, lock-screen controls, AirPlay, Cast, Picture in Picture, and low-latency live streaming are not supported yet.
- Manual quality constraints are supported, but custom automatic bitrate policy controls are not exposed yet.
- iOS HLS playback is still delegated to AVFoundation. iOS HLS disk prefetch only commits to common VOD playlists. Live/event playlists, `#EXT-X-BYTERANGE`, I-frame-only playlists, complex encryption, and DRM playlists report an `unsupported_hls_playlist` cache error; playback is not failed by that guard.
- Changing cache capacity and clearing cache require no active players or standalone download tasks. Download concurrency can be changed at runtime, but running tasks are not force-cancelled.
- Native task queues are not restored after app restart. The example persists download records and restores completed cache records through `sourceInfo`.
- Before commercial pilot usage, run the automated checks and real-device checklist in `COMMERCIAL_ACCEPTANCE.md`.

### Example App

The example app uses Chinese by default and provides a top-bar language button to switch between Chinese and English. It includes multiple public HLS and MP4 test sources for playback switching, quality selection, cache, seek-aware prefetch, and progressive playback validation:

The More sheet opens the download list. Download items use `metadata.title` as the display name, and completed items can be tapped to switch to the corresponding source and play through the local cache. The cache/download metrics panel above QoE separates player-owned cache from standalone downloads. Downloading the current source reuses an existing task or completed cache record to avoid duplicate same-source work.

| Name | URL |
| --- | --- |
| Apple BipBop | `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8` |
| Google Shaka Angel One | `https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8` |
| Google Shaka Big Buck Bunny | `https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8` |
| Mux Tears of Steel | `https://test-streams.mux.dev/tos_ismc/main.m3u8` |
| Akamai HLS Test | `https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8` |
| AWS CloudFront Sintel | `https://d2zihajmogu5jn.cloudfront.net/sintel/master.m3u8` |
| MP4 Video.js Oceans | `https://vjs.zencdn.net/v/oceans.mp4` |
| MP4 W3C Sintel Trailer | `https://media.w3.org/2010/05/sintel/trailer.mp4` |
| MP4 W3Schools Big Buck Bunny | `https://www.w3schools.com/html/mov_bbb.mp4` |
| MP4 MDN Flower | `https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4` |

The example page also includes playback controls, playlist switching, standalone disk prefetch controls, playback-health stats, and a QoE snapshot panel for real-device debugging. It shows recent rebuffer ratio, dropped-frame deltas, recovery deltas, quality-switch deltas, and can copy the latest snapshot JSON.

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
