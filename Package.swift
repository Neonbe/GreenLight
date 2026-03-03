// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GreenLight",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/alienator88/AlinFoundation.git", branch: "main"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "GreenLight",
            dependencies: ["AlinFoundation", "Sparkle"],
            path: "GreenLight",
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GreenLightTests",
            dependencies: ["GreenLight"],
            path: "GreenLightTests"
        ),
    ]
)
