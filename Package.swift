// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "HueControlBar",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "HueControlBar", targets: ["HueControlBar"]),
    ],
    dependencies: [
        .package(url: "https://your-host/HueColorCore.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "HueControlBar", dependencies: []),
        .testTarget(name: "HueControlBarTests", dependencies: ["HueControlBar"]),
    ]
)
