// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "HueControlBar",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "HueControlBar", targets: ["HueControlBar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Loakesy/HueColors", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "HueControlBar",
            dependencies: [
                .product(name: "HueColors", package: "HueColors")
            ]
        ),
        .testTarget(
            name: "HueControlBarTests",
            dependencies: ["HueControlBar"]
        ),
    ]
)
