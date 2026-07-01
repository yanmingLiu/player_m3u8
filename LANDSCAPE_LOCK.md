# 横屏控制锁

## 当前状态

`player_m3u8` 的插件核心只负责 Texture 播放、状态、缓存和预取，不提供方向锁定或控制锁 API。

example 页面已有全屏入口和系统方向控制：手动进入全屏时直接请求系统切到 `landscapeLeft`/`landscapeRight`，退出后恢复为允许系统方向。此前横屏控制图层没有锁定按钮。

## 行为

横屏控制锁是 example 播放器图层能力，只在 `ExampleVideoScaffold(isFullscreen: true)` 时出现：

- 未锁定时，横屏顶部控制条会在标题右侧、更多按钮左侧显示 `lock_open` 按钮。
- 点击锁定后，隐藏返回、标题、更多、进度条、播放、字幕、倍速、清晰度和选集等完整控制层。
- 锁定后只保留 `lock` 解锁按钮，位置在横屏画面左侧中部偏下，方便单手点击。
- 锁定后禁用 `M3u8PlayerGestureControls`，避免亮度、音量和 seek 手势误触。
- 点击解锁按钮后恢复完整横屏控制层。
- 竖屏下手动点击全屏会请求 `landscapeLeft`/`landscapeRight`，并临时保持横屏方向；这样手机实际仍竖拿时不会被方向监听自动退回竖屏。
- 手动全屏后会监听设备物理方向：当传感器确认手机已经横放时，只重置手动保护，不立即释放横屏方向限制，避免出现竖屏到横屏的跳动；之后手机再物理转回竖屏，会自动退出全屏并恢复系统方向。
- 未锁定时监听布局和物理方向变化：竖屏页面物理旋转到横屏会自动进入横屏全屏，旋转自动进入的横屏在物理转回竖屏时会自动退出全屏。
- 锁定时保持横屏观看状态，旋转回竖屏不会自动退出全屏。
- 播放、缓存、磁盘预取和当前 source 不受控制锁影响。

## 平台差异

控制锁和自动横竖屏切换都在 Flutter UI 层实现，Android 和 iOS 行为一致。手动全屏后的物理横竖屏识别使用 example 里的 `sensors_plus` 加速度计数据，不进入 `player_m3u8` 插件核心 API。

Android 仍使用 Media3 ExoPlayer，iOS 仍使用 AVFoundation；本功能不会重建 native player，也不会改动 Texture 渲染方式。系统横屏能力仍沿用 example 页面已有的 `SystemChrome` 调用和宿主工程方向配置。

## 性能影响

控制锁只切换少量 Flutter widget 状态：

- 不释放或重建 native player。
- 不改变播放器 forward buffer。
- 不启动或取消磁盘预取任务。
- 不影响已写入磁盘的缓存数据复用。

锁定状态下手势识别关闭，可减少横屏观看时的误触和无效手势处理。自动旋转只触发页面 chrome 和布局状态切换，不改变播放源。物理方向监听使用系统传感器的普通采样间隔，只更新少量布尔状态。

## 接入点

实现位于 `example/lib/src/video_scaffold.dart`：

- `LandscapePlayerControls` 显示锁定入口。
- `LockedLandscapeControls` 显示锁定后的解锁入口。
- `_ExampleVideoScaffoldState` 根据页面传入的锁定状态切换 `M3u8GestureControlsConfig`。
- `PlayerExamplePage` 监听 `MediaQuery.orientationOf(context)`，未锁定时自动进出全屏，锁定时保持横屏方向策略。

文案位于 `example/lib/src/example_strings.dart`：

- `lockControlsTooltip`
- `unlockControlsTooltip`

## 验证

常规验证命令：

```sh
flutter analyze
flutter test
cd example && flutter test
```

本功能不涉及原生代码。需要做完整回归时可额外运行：

```sh
cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
```
