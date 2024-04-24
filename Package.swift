// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "PulseNetwork",
    platforms: [
        .iOS(.v14),
        .tvOS(.v15),
        .macOS(.v12),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "PulseNetwork", targets: ["PulseNetwork"]),
        .library(name: "PulseUI", targets: ["PulseUI"])
    ],
    targets: [
        .target(name: "PulseNetwork"),
        .target(name: "PulseUI", dependencies: ["PulseNetwork"]),
        .testTarget(name: "PulseTests", dependencies: ["PulseNetwork"]),
        .testTarget(name: "PulseUITests", dependencies: ["PulseUI"])
    ]
)
