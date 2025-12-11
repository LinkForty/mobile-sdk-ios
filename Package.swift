// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LinkFortySDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // The main LinkForty SDK library
        .library(
            name: "LinkFortySDK",
            targets: ["LinkFortySDK"]
        ),
    ],
    dependencies: [
        // No external dependencies - keeping it lightweight
    ],
    targets: [
        // Main SDK target
        .target(
            name: "LinkFortySDK",
            dependencies: [],
            path: "Sources/LinkFortySDK",
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        ),

        // Unit tests
        .testTarget(
            name: "LinkFortySDKTests",
            dependencies: ["LinkFortySDK"],
            path: "Tests/LinkFortySDKTests"
        ),
    ]
)
