//swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Kiri",
  dependencies: [
    .package(url: "https://github.com/apple/swift-log", exact: "1.9.1"),
  ],
  targets: [
    .target(
      name: "KiriFFI",
      publicHeadersPath: "include",
      linkerSettings: [
        .unsafeFlags(["-L", "../artifacts"])
      ]
    ),
    .target(
      name: "Kiri",
      dependencies: [
        "KiriFFI",
        .product(name: "Logging", package: "swift-log"),
      ]
    ),
    .testTarget(
      name: "KiriTests",
      dependencies: ["Kiri"]
    ),
    .executableTarget(
      name: "KiriBench",
      dependencies: [.target(name: "Kiri")],
      swiftSettings: [
        .define("KIRI_BENCH", .when(configuration: .release))
      ],
    ),
  ],
)
