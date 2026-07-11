// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassesKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GlassesKit", targets: ["GlassesKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/meta-wearables-dat-ios", exact: "0.5.0")
    ],
    targets: [
        .target(
            name: "GlassesKit",
            dependencies: [
                .product(name: "MWDATCore", package: "meta-wearables-dat-ios"),
                .product(name: "MWDATCamera", package: "meta-wearables-dat-ios"),
                .product(name: "MWDATMockDevice", package: "meta-wearables-dat-ios")
            ]
        )
    ]
)
