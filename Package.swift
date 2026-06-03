// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiddleClickMagic",
    targets: [
        .target(
            name: "MiddleClickMagicCore"
        ),
        .executableTarget(
            name: "MiddleClickMagic",
            dependencies: ["MiddleClickMagicCore"]
        ),
        .testTarget(
            name: "MiddleClickMagicTests",
            dependencies: ["MiddleClickMagicCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
