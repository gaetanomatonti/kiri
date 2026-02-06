// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "VaporBench",
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
