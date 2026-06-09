# player_m3u8

A Flutter plugin for playing network HLS/m3u8 video on iOS and Android.

The plugin renders video through Flutter textures. Android uses Media3 ExoPlayer,
and iOS uses AVFoundation with `AVPlayerItemVideoOutput`.

## Usage

```dart
final controller = M3u8PlayerController();

await controller.initialize(
  'https://example.com/index.m3u8',
  headers: const {'User-Agent': 'MyApp'},
);
await controller.play();

M3u8Player(controller: controller);
```

For a playlist, reuse the same controller and switch the source:

```dart
await controller.setSource(nextUrl, autoPlay: true);
```

`setSource` disposes the previous native player and cancels its active prefetch
task before creating the next player. Disk files already cached by previous
sources remain in the app cache for reuse.

This means only the current source continues playback and disk prefetch. If the
user switches away from a video, its active downloader is stopped. If the user
switches back later, the source starts again and resumes using data that was
already written to the app cache.

Dispose the controller with the owning widget:

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

## Supported in v0.0.1

- Network HLS/m3u8 playback.
- Play, pause, seek, and dispose.
- Playlist source switching through `setSource`.
- Texture-based rendering.
- Playback state, progress, duration, buffered position, disk cache position,
  video size, and errors.
- Bounded player buffering for low memory usage.
- Best-effort VOD disk prefetch for the current source while the player is
  alive, including while paused. Android playback and prefetch share the same
  Media3 `SimpleCache`. iOS stores prefetched HLS resources under the app
  caches directory and reports progress without increasing AVPlayer's in-memory
  forward buffer.

The bundled example app includes a playlist with these HLS sources:

- `https://prod-gg.niftyvaughanpxnew.com/movies/795bf902-1d7a-4811-af9e-239f0a232f3a-216100/index.m3u8`
- `https://prod-gg.niftyvaughanpxnew.com/movies/7b318dc9-64cb-49dd-bdc0-d28b80f6ed53-292394/index.m3u8`
- `https://prod-gg.niftyvaughanpxnew.com/movies/b6cf4a77-6fa1-4b15-b5ec-f440b923c281-198867/index.m3u8`
- `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`
- `https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8`
- `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8`

## Verification

```sh
flutter analyze
flutter test
cd example && flutter test
cd example/android && ./gradlew testDebugUnitTest
cd ../.. && cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
```
