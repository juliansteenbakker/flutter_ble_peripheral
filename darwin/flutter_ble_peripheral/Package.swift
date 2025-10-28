// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_ble_peripheral",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "flutter-ble-peripheral", targets: ["flutter_ble_peripheral"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_ble_peripheral",
            dependencies: [],
            resources: [
                .process("Resources"),
            ]
        )
    ]
)
