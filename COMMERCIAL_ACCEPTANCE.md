# player_m3u8 商用试点验收清单

这份清单用于发布或接入前验收。当前目标是小规模商用试点，不代表已经覆盖 DRM、直播、低延迟直播、投屏、后台播放或画中画等完整商业播放器能力。

## 自动化检查

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `cd example && flutter test`
- [ ] `cd example/android && ./gradlew testDebugUnitTest`
- [ ] `cd example && flutter build apk --debug`
- [ ] `cd example && flutter build ios --simulator --debug`

## 手动播放矩阵

- [ ] Android 真机播放至少 2 个 HLS VOD，覆盖 master playlist 和 media playlist。
- [ ] iOS 真机播放至少 2 个 HLS VOD，覆盖 master playlist 和 media playlist。
- [ ] Android/iOS 各播放 1 个 progressive MP4。
- [ ] Android/iOS 各播放 1 个带内嵌字幕或外部 WebVTT 的 HLS VOD。
- [ ] Android/iOS 各播放 1 个多音轨 HLS VOD，并验证音轨切换。
- [ ] Android/iOS 各验证 Auto 和手动清晰度切换。

## 生命周期和交互

- [ ] 使用 `M3u8PlayerController.setSource(...)` 连续切换至少 20 次，确认旧画面、旧声音、旧主动预取都停止。
- [ ] seek 后确认当前 source 的主动预取从新位置附近重新开始。
- [ ] 暂停播放后确认当前 source 可以继续磁盘预取，直到完成、dispose 或 source 切换。
- [ ] 前后台切换后确认播放、暂停、进度、画面恢复符合业务预期。
- [ ] 横竖屏切换后确认 Texture 尺寸、字幕 overlay、控制层无错位。
- [ ] dispose 后确认没有继续播放、继续主动预取或继续发送旧 player 事件。

## 缓存和弱网

- [ ] 独立预缓存任务支持排队、运行、暂停、恢复、取消、完成和错误状态展示。
- [ ] 播放中降低 `maxConcurrentPrecacheTasks` 后，独立下载不会和当前播放严重抢占网络/IO。
- [ ] 缓存容量变更和全量清理在有活跃 player 或任务时返回 `active_players` / `active_cache_tasks`。
- [ ] Android HLS 预取复用 Media3 cache，重复播放有缓存命中。
- [ ] iOS HLS VOD 预取可完成并复用 app caches。
- [ ] iOS live/event/byterange/unsupported encryption playlist 预取返回 `unsupported_hls_playlist`，播放链路继续交给 AVFoundation。
- [ ] 弱网、断网、恢复网络时，错误事件和 retry/recovery 行为可观测。

## 长时间和性能

- [ ] Android/iOS 各连续播放 30 分钟以上，无明显内存持续增长。
- [ ] Android/iOS 各连续 seek 50 次，无崩溃、无旧 source 任务残留。
- [ ] QoE 指标能上报首帧耗时、rebuffer 次数/时长、丢帧、带宽、清晰度切换次数。
- [ ] 缓存目录不会超过配置容量，清理后缓存信息归零或接近归零。

## 已知不在本轮范围

- DRM / FairPlay / Widevine
- live HLS / EVENT playlist / LL-HLS 的完整缓存
- AirPlay / Cast
- Picture in Picture
- 锁屏控制和后台播放
- 自定义网络栈、证书 pinning、代理、离线授权
