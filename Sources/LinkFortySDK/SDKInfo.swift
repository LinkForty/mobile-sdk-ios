//
//  SDKInfo.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Identifies this SDK (name + version) on outbound requests so the backend can
/// report which SDKs/versions are in use and flag outdated integrations.
///
/// - Important: `version` is hardcoded because Swift Package Manager exposes no
///   reliable runtime version for the package itself. Bump it together with the
///   release tag and the CHANGELOG entry so the reported version stays accurate.
enum SDKInfo {
    /// SDK platform identifier, sent as `sdkName` (and in the `X-LinkForty-SDK` header).
    static let name = "ios"

    /// SDK release version, sent as `sdkVersion`. Keep in sync with the git tag.
    static let version = "1.4.0"
}
