// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Stevenson",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0")
    ],
    targets: [
        .target(name: "Stevenson", dependencies: ["Vapor"]),
        .target(name: "App", dependencies: ["Stevenson", "Utility"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

