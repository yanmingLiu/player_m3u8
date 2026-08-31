# player_m3u8_example

Demonstrates the `player_m3u8` plugin with a Texture-based HLS player on iOS and Android.

The example app uses Chinese by default and provides a top-bar language button to switch between Chinese and English. It includes playback controls, playlist switching, standalone disk prefetch controls, playback-health stats, and a QoE snapshot panel.

## Code Organization

The example is organized by feature rather than by widget type:

```text
lib/
├── main.dart                         # executable bootstrap only
├── app/                               # MaterialApp and feature entry list
├── features/
│   ├── player/
│   │   ├── data/                      # sample sources and download records
│   │   └── presentation/             # page, controls, panels and sheets
│   └── drama/
│       ├── data/                      # models and asset repository
│       └── presentation/             # feed, playback page and overlays
└── shared/
    ├── localization/                 # example UI strings
    ├── formatters.dart                # duration/bytes/speed formatting
    └── widgets/                      # reusable controls
```

`main.dart` only starts the app. The app home lists the independent features and pushes each one as a separate route. Feature pages own orchestration and lifecycle, while repositories and persistence services own I/O. The player page keeps one native `M3u8PlayerController`; the drama playback page reuses that controller across `PageView` items and leaves prefetch tasks independent from playback. New code should import from `app/`, `features/`, or `shared/` directly.

## Test Sources

The built-in playlist uses public HLS test streams:

| Name | URL |
| --- | --- |
| Apple BipBop | `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8` |
| Google Shaka Angel One | `https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8` |
| Google Shaka Big Buck Bunny | `https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8` |
| Mux Tears of Steel | `https://test-streams.mux.dev/tos_ismc/main.m3u8` |
| Akamai HLS Test | `https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8` |
| AWS CloudFront Sintel | `https://d2zihajmogu5jn.cloudfront.net/sintel/master.m3u8` |

## Run

```sh
flutter run
```

## Test

```sh
flutter test
```

From the repository root, the standard validation is:

```sh
flutter analyze
flutter test
cd example && flutter test
```
