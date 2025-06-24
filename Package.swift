// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Osiris",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Osiris",
            targets: ["Osiris"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Osiris",
            dependencies: []),
        .testTarget(
            name: "OsirisTests",
            dependencies: ["Osiris"],
            resources: [
                .copy("Resources/lorem.txt"),
                .copy("Resources/notbad.jpg"),
            ]),
    ]
)
