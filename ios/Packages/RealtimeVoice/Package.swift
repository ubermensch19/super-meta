// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RealtimeVoice",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "RealtimeVoice", targets: ["RealtimeVoice"])
    ],
    targets: [
        .target(name: "RealtimeVoice"),
        .testTarget(name: "RealtimeVoiceTests", dependencies: ["RealtimeVoice"])
    ]
)
