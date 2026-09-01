// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "player_m3u8",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "player-m3u8", targets: ["player_m3u8"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "player_m3u8",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
