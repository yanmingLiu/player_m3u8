# player_m3u8 Error Codes

This document lists stable error codes returned by `PlayerM3u8PlatformException`, `M3u8PlayerError`, and `M3u8CacheEvent.error`. Treat unknown codes as retryable only when your product policy allows it.

## Playback And Player Commands

| Code | Platform | Trigger | Suggested Handling |
| --- | --- | --- | --- |
| `invalid_url` | Android/iOS | `videoUrl` is empty or cannot be parsed. | Reject the source before creating the player. |
| `invalid_player_id` | Android/iOS/Dart | A command is missing `playerId` or native returned a null player id. | Recreate the controller/player and report a client bug. |
| `unknown_player` | Android/iOS | Command targets a disposed or unknown native player. | Stop sending commands for that controller; recreate if playback is still needed. |
| `invalid_position` | Android/iOS | `seekTo` or initial position is negative or missing. | Clamp to zero before calling the API. |
| `invalid_initial_position` | Android/iOS | `initialPosition` is negative. | Clamp to zero before calling `initialize`, `setSource`, or `precache`. |
| `invalid_playback_speed` | Android/iOS | Speed is not finite or outside `0.25..2.0`. | Clamp or disable unsupported UI values. |
| `invalid_volume` | Android/iOS | Volume is not finite or outside `0.0..1.0`. | Clamp before calling the API. |
| `invalid_muted` | Android/iOS | Missing `isMuted` argument. | Treat as a client integration bug. |
| `invalid_quality` | Android/iOS | Missing quality payload. | Use `M3u8Quality.auto` or one item from `availableQualities`. |
| `unsupported_source_type` | Android/iOS | Operation is not supported for the current source, for example quality selection on MP4/MOV. | Hide that control for unsupported sources. |
| `player_error` | Dart fallback | Native error payload was missing. | Log `diagnostics` and let the user retry. |
| `playback_error` | iOS fallback | AVFoundation failed without a specific domain. | Log `details.diagnostics`, then retry or switch source. |
| Media3 `ERROR_CODE_*` | Android | ExoPlayer playback failure. | Use `error.details.type`, `cause`, and `diagnostics` for source/renderer/network attribution. |
| AVFoundation domain codes | iOS | AVPlayer/AVPlayerItem failure. | Use `error.details.domain`, `code`, `userInfo`, and `diagnostics` for attribution. |

## Cache Configuration And Tasks

| Code | Platform | Trigger | Suggested Handling |
| --- | --- | --- | --- |
| `invalid_cache_size` | Android/iOS | Cache size is missing or not greater than zero. | Use a positive byte size. |
| `invalid_cache_concurrency` | Android/iOS | `maxConcurrentPrecacheTasks` is less than 1. | Use at least 1. |
| `active_players` | Android/iOS | Cache capacity or clearing is attempted while native players exist. | Dispose players first, or only change download concurrency. |
| `active_cache_tasks` | Android/iOS | Cache capacity or clearing is attempted while standalone tasks exist. | Cancel or wait for tasks first. |
| `cache_in_use` | Android | Media3 cache cannot be reconfigured safely. | Retry after all players/tasks are disposed. |
| `cache_config_failed` | iOS | Cache configuration failed at the filesystem layer. | Log details and keep the previous cache config. |
| `cache_clear_failed` | iOS | Cache clearing failed at the filesystem layer. | Retry after active file handles are released. |
| `cache_info_failed` | iOS | Cache info/source info failed at the filesystem layer. | Log and retry later. |
| `invalid_cache_info` | Dart | Native cache info payload is missing or invalid. | Treat as plugin/native integration failure. |
| `invalid_cache_task` | Android/iOS/Dart | Task id is empty, missing, or native returned a null task id. | Validate ids before calling pause/resume/cancel. |
| `unknown_cache_task` | Android/iOS | Task id does not exist in the active native queue. | Remove the task from UI; completed tasks are not kept in the native queue. |
| `invalid_max_retries` | Android/iOS | `maxRetries` is negative. | Use zero or a positive retry count. |
| `cache_error` | Android/iOS | Generic prefetch/download failure. | Log `event.error.details` when available and allow retry. |
| `unsupported_hls_playlist` | iOS | HLS disk prefetch found live/event/byterange/I-frame-only/complex encrypted or DRM playlist. | Continue playback through AVFoundation; disable offline/prefetch UI for that source. |

## Diagnostics

Playback events expose `diagnostics` and playback errors include `details.diagnostics` when available. These fields are intended for production attribution:

- `sessionId`: native playback session id.
- `sourceId`: short source identifier, not the full URL.
- `sourceType`: `hls`, `progressive`, or platform equivalent.
- `positionMs`, `durationMs`, `bufferedPositionMs`: playback state at event time.
- `platform`: `android` or `ios`.
- `hasCacheKey`, `hasAudioUrl`: source configuration flags.

Do not place secrets in source URLs, headers, or `cacheKey` if your analytics pipeline forwards diagnostics or error details.
