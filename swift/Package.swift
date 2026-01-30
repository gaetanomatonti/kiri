//swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Kiri",
  platforms: [.macOS(.v26)],
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
      dependencies: ["KiriFFI"]
    ),
    .executableTarget(
      name: "KiriBench",
      dependencies: [.target(name: "Kiri")]
    ),
  ]
)
