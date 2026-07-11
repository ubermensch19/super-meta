// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIProviders",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AIProviders", targets: ["AIProviders"])
    ],
    targets: [
        .target(name: "AIProviders"),
        .testTarget(name: "AIProvidersTests", dependencies: ["AIProviders"])
    ]
)
