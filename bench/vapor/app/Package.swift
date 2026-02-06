// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "VaporBench",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "VaporBench", targets: ["App"]),
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
      ]
    ),
  ]
)
