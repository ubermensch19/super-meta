// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentGateway",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AgentGateway", targets: ["AgentGateway"])
    ],
    targets: [
        .target(name: "AgentGateway"),
        .testTarget(name: "AgentGatewayTests", dependencies: ["AgentGateway"])
    ]
)
