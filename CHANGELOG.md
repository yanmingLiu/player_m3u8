## 0.1.2

### 中文

- 修复 iOS Texture 黑屏问题：`AVPlayerItemVideoOutput` 现在输出 IOSurface-backed `CVPixelBuffer`，确保 Flutter/Metal 合成路径能显示真实视频帧。
- iOS HLS 播放主链路恢复为直接 AVPlayer 播放远程 HLS，避免磁盘预取和 ResourceLoader 影响播放兼容性；独立预缓存能力保留。
- 改进 iOS 取帧节奏、seek/播放后的帧刷新通知，以及首帧/空帧/像素缓冲诊断字段。
- 修复 Flutter Texture 初始化死锁：拿到 native texture id 后即创建 `Texture`，在真实视频尺寸返回前使用 16:9 临时尺寸。
- 播放、平台调用、缓存/下载错误现在会在 debug 控制台输出结构化上下文；example 会通过 SnackBar 反馈播放、下载和操作错误。
- Android HLS/progressive 缓存错误事件新增 `details`，并同步输出 Logcat，方便定位任务、URL、分片、重试和底层异常。
- 收紧 iOS 播放 diagnostics，不再输出完整播放 URL，并改用更稳健的 HLS master playlist parser 解析清晰度列表。
- example 默认源切换为 Mux Big Buck Bunny，便于验证 iOS HLS 画面渲染。

### English

- Fixed iOS Texture black screen rendering. `AVPlayerItemVideoOutput` now emits IOSurface-backed `CVPixelBuffer` frames so Flutter/Metal can composite actual video frames.
- Restored direct AVPlayer remote-HLS playback as the primary iOS playback path to avoid disk-prefetch and ResourceLoader interference; standalone precache remains available.
- Improved iOS frame sampling cadence, frame refresh notifications after play/seek, and first-frame, nil-frame, and pixel-buffer diagnostics.
- Fixed Flutter Texture initialization deadlock by creating the `Texture` as soon as the native texture id is available, using a temporary 16:9 size until the real video size is reported.
- Playback, platform-call, cache, and download errors now print structured debug context; the example app surfaces playback, download, and action failures through SnackBars.
- Android HLS/progressive cache error events now include `details` and Logcat output with task, URL, segment, retry, and underlying exception context.
- Tightened iOS playback diagnostics so full playback URLs are no longer emitted, and switched HLS quality discovery to a more robust master-playlist parser.
- Switched the example default source to Mux Big Buck Bunny for easier iOS HLS rendering verification.

## 0.1.0

### 中文

- 增加商用试点边界说明和 `COMMERCIAL_ACCEPTANCE.md` 验收清单，明确自动化检查、真机播放矩阵、弱网/缓存/生命周期验收项。
- iOS HLS 磁盘预取新增 playlist capability guard；live/event playlist、`#EXT-X-BYTERANGE`、I-frame-only、复杂加密或 DRM playlist 会上报 `unsupported_hls_playlist`，播放链路继续交给 AVFoundation。
- 播放事件新增跨平台 `diagnostics` 上下文，包含 session/source 标识、sourceType、播放位置、缓冲位置、平台和缓存 key 状态，便于线上错误和 QoE 归因。
- 补充 Android、iOS 和 Dart 测试覆盖，强化缓存任务参数校验、未知任务错误、HLS capability 判断和 cache error code 解析。
- README 明确当前不支持 DRM/FairPlay/Widevine、后台播放、锁屏控制、AirPlay、Cast、Picture in Picture、低延迟直播，以及 iOS progressive 外部字幕限制。
- 初始化 Flutter HLS/m3u8 播放插件。
- 增强缓存系统：支持 source 级 `cacheKey`、独立预缓存任务列表、暂停/恢复/取消、优先级、并发限制、source 级缓存查询/清理，以及扩展缓存观测字段。
- 支持 progressive MP4/MOV 独立磁盘预取；Android 复用 Media3 `SimpleCache`，iOS 完整预取后复用 app caches 文件。
- example 将 More sheet 的“不感兴趣”替换为下载列表，并在 QoE 面板上方新增缓存/下载指标看板。
- 明确区分播放器内部磁盘缓存和业务独立下载任务；下载列表只展示独立任务，内部缓存只进入播放器缓存指标。
- example 下载列表支持显示资源名称、暂停/恢复/取消、完成后点击本地缓存播放，并持久化下载记录用于启动后恢复已完成任务。
- `configure` 支持运行期调整 `maxConcurrentPrecacheTasks`；缓存容量变更和全量清理仍要求没有活跃播放器和独立下载任务。
- example 对当前 source 下载做同源去重，播放活跃时将独立下载并发降为 1，降低缓存和下载同时进行时的网络/IO 压力。
- 支持 iOS 和 Android Texture 渲染。
- Android 使用 Media3 ExoPlayer，iOS 使用 AVFoundation。
- 支持播放、暂停、seek、dispose、播放列表 source 切换。
- 支持播放状态、进度、播放器缓冲、磁盘缓存进度、视频尺寸和错误事件。
- 支持当前 source 的磁盘预取；切换 source 时取消旧 source 主动缓存任务。
- example 提供播放列表、上一条/下一条、跳转、三层进度条和缓存进度展示。

### English

- Added commercial-pilot boundaries and `COMMERCIAL_ACCEPTANCE.md` with automated checks, real-device playback matrix, weak-network, cache, and lifecycle acceptance items.
- Added an iOS HLS disk-prefetch playlist capability guard. Live/event playlists, `#EXT-X-BYTERANGE`, I-frame-only playlists, complex encryption, and DRM playlists now report `unsupported_hls_playlist` while playback remains delegated to AVFoundation.
- Added cross-platform `diagnostics` context to playback events with session/source identifiers, sourceType, playback position, buffered position, platform, and cache-key state for production error and QoE attribution.
- Expanded Android, iOS, and Dart tests for cache task validation, unknown task errors, HLS capability detection, and cache error-code parsing.
- README now explicitly documents unsupported DRM/FairPlay/Widevine, background playback, lock-screen controls, AirPlay, Cast, Picture in Picture, low-latency live streaming, and iOS progressive external subtitle limitations.
- Initial Flutter HLS/m3u8 player plugin.
- Expanded cache support with source-level `cacheKey`, standalone cache task listing, pause/resume/cancel, priority, concurrency limit, source-level cache info/clear, and richer cache telemetry.
- Added standalone progressive MP4/MOV disk precache. Android reuses Media3 `SimpleCache`; iOS reuses fully cached app cache files.
- The example replaces the More sheet "Not interested" action with a download list and adds a cache/download metrics panel above QoE snapshots.
- Clarified player-owned disk cache versus app-owned standalone download tasks. The download list shows only standalone tasks, while player-owned cache is surfaced through player cache metrics.
- The example download list shows resource names, supports pause/resume/cancel, opens completed items through local cache playback, and persists records to restore completed tasks after restart.
- `configure` can adjust `maxConcurrentPrecacheTasks` at runtime. Cache capacity changes and full cache clearing still require no active players or standalone download tasks.
- The example de-duplicates current-source downloads and lowers standalone download concurrency to 1 while playback is active to reduce network and IO contention.
- Added Texture rendering support for iOS and Android.
- Android uses Media3 ExoPlayer; iOS uses AVFoundation.
- Added play, pause, seek, dispose, and playlist source switching.
- Added playback state, position, player buffer, disk cache progress, video size, and error events.
- Added disk prefetch for the current source; switching source cancels the previous active prefetch task.
- Added an example app with playlist switching, previous/next controls, a layered progress bar, and cache progress display.
