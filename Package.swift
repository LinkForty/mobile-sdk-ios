// swift-tools-version: 5.9

// LinkForty iOS SDK — open-source alternative to Branch.io, AppsFlyer OneLink,
// and Firebase Dynamic Links. Deferred deep linking, mobile attribution, and
// smart link routing for iOS. Self-hosted, privacy-first, no per-click pricing.
// https://github.com/LinkForty/mobile-sdk-ios

import PackageDescription

let package = Package(
    name: "LinkFortySDK",
    platforms: [
        .iOS(.v16)
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
