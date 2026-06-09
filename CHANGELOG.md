## 0.0.1

### 中文

- 初始化 Flutter HLS/m3u8 播放插件。
- 支持 iOS 和 Android Texture 渲染。
- Android 使用 Media3 ExoPlayer，iOS 使用 AVFoundation。
- 支持播放、暂停、seek、dispose、播放列表 source 切换。
- 支持播放状态、进度、播放器缓冲、磁盘缓存进度、视频尺寸和错误事件。
- 支持当前 source 的磁盘预取；切换 source 时取消旧 source 主动缓存任务。
- example 提供播放列表、上一条/下一条、跳转、三层进度条和缓存进度展示。

### English

- Initial Flutter HLS/m3u8 player plugin.
- Added Texture rendering support for iOS and Android.
- Android uses Media3 ExoPlayer; iOS uses AVFoundation.
- Added play, pause, seek, dispose, and playlist source switching.
- Added playback state, position, player buffer, disk cache progress, video size, and error events.
- Added disk prefetch for the current source; switching source cancels the previous active prefetch task.
- Added an example app with playlist switching, previous/next controls, a layered progress bar, and cache progress display.
