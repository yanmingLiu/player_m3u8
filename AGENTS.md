# AGENTS.md

## Communication

- 回复使用中文。
- 说明实现时聚焦插件行为、平台差异、性能影响和验证结果。

## Project

- 这是 Flutter plugin：`player_m3u8`。
- 支持平台：Android 和 iOS。
- 渲染方式：Flutter `Texture`，不要改成 PlatformView。
- Android 使用 Media3 ExoPlayer。
- Android HLS 播放和磁盘预取优先使用 Media3 自带能力，例如 `HlsMediaSource`、`HlsDownloader`、`HlsPlaylistParser`、`CacheWriter`，不要手写 m3u8 分片解析作为主链路。
- iOS 使用 AVFoundation。

## Playback And Cache Rules

- 播放器内存缓冲必须保持有界，不要通过扩大原生播放器 forward buffer 来实现完整缓存。
- 完整缓存/预取走磁盘缓存或下载任务。
- 列表切换使用 `M3u8PlayerController.setSource(...)`。
- 切换 source 时必须释放旧 native player，并取消旧 source 的主动预下载任务。
- 旧 source 已经写入磁盘的数据可以保留复用，但旧 source 不应继续后台下载。
- 当前 source 暂停播放时可以继续磁盘预取，直到完成或 dispose/source 切换。
- 当前 source seek 后应取消当前主动预取，并从 seek 目标时间对应的分片开始优先预取。

## Validation

常规修改后至少运行：

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

## Git

- 不提交本地构建产物、截图、`.dart_tool`、`build`、Pods 等生成文件。
- 提交前检查 `git status --short`。
