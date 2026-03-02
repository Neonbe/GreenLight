// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GreenLight",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/alienator88/AlinFoundation.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "GreenLight",
            dependencies: ["AlinFoundation"],
            path: "GreenLight",
            exclude: ["Info.plist", "Resources"]
        ),
        .testTarget(
            name: "GreenLightTests",
            dependencies: ["GreenLight"],
            path: "GreenLightTests"
        ),
    ]
)
