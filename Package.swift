// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "bennie",
  platforms: [.macOS(.v10_15)],
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
