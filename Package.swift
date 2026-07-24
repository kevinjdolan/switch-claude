// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeSwapMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeSwapMac",
            path: "Sources/ClaudeSwapMac"
        )
    ]
)
