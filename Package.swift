// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwitchClaude",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SwitchClaude",
            path: "Sources/SwitchClaude"
        )
    ]
)
