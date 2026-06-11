## 0.0.1

### 中文

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
