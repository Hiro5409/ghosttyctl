// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ghosttyctl",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "ghosttyctl", targets: ["GhosttyCtl"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "GhosttyCtl",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Subprocess", package: "swift-subprocess"),
      ]
    ),
    .testTarget(
      name: "GhosttyCtlTests",
      dependencies: ["GhosttyCtl"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
