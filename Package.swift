// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Stevenson",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "Stevenson", dependencies: ["Vapor"]),
        .target(name: "App", dependencies: ["Stevenson"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

