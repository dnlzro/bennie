// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "bennie",
  platforms: [.macOS(.v10_15)],
  products: [
    .executable(name: "bennie", targets: ["bennie"]),
  ],
  targets: [
    .executableTarget(
      name: "bennie",
      path: "Sources"
    ),
    .testTarget(
      name: "bennieTests",
      dependencies: ["bennie"],
      path: "Tests"
    ),
  ]
)
