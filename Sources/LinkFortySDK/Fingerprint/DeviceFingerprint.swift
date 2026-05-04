//
//  DeviceFingerprint.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Device fingerprint for attribution matching
struct DeviceFingerprint: Codable {
    /// User-Agent string (e.g., "MyApp/1.0 iOS/15.0")
    let userAgent: String

    /// Timezone identifier (e.g., "America/New_York")
    let timezone: String

    /// Preferred language (e.g., "en-US")
    let language: String

    /// Screen width in pixels
    let screenWidth: Int

    /// Screen height in pixels
    let screenHeight: Int

    /// Platform name (always "iOS")
    let platform: String

    /// Platform version (e.g., "15.0")
    let platformVersion: String

    /// App version (e.g., "1.0.0")
    let appVersion: String

    /// Optional device ID (IDFA, IDFV, or custom) - only if user consented
    let deviceId: String?

    /// Attribution window in hours
    let attributionWindowHours: Int

    /// Optional public workspace token (LinkForty Cloud only). Lets the
    /// server scope organic installs to the right workspace. Encoded only
    /// when present so legacy/self-hosted servers see the same payload
    /// they always have.
    let appToken: String?

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case userAgent
        case timezone
        case language
        case screenWidth
        case screenHeight
        case platform
        case platformVersion
        case appVersion
        case deviceId
        case attributionWindowHours
        case appToken
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userAgent, forKey: .userAgent)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(language, forKey: .language)
        try container.encode(screenWidth, forKey: .screenWidth)
        try container.encode(screenHeight, forKey: .screenHeight)
        try container.encode(platform, forKey: .platform)
        try container.encode(platformVersion, forKey: .platformVersion)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
        try container.encode(attributionWindowHours, forKey: .attributionWindowHours)
        try container.encodeIfPresent(appToken, forKey: .appToken)
    }
}

// MARK: - CustomStringConvertible

extension DeviceFingerprint: CustomStringConvertible {
    var description: String {
        """
        DeviceFingerprint(
            userAgent: \(userAgent),
            timezone: \(timezone),
            language: \(language),
            screen: \(screenWidth)x\(screenHeight),
            platform: \(platform) \(platformVersion),
            appVersion: \(appVersion)
        )
        """
    }
}
