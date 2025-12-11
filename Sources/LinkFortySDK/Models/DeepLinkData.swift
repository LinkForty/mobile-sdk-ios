//
//  DeepLinkData.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Deep link data returned from attribution or direct deep links
public struct DeepLinkData: Codable, Equatable {
    /// The short code of the link (e.g., "abc123")
    public let shortCode: String

    /// iOS-specific URL (Universal Link or custom scheme)
    public let iosURL: String?

    /// Android-specific URL (App Link or custom scheme)
    public let androidURL: String?

    /// Web fallback URL
    public let webURL: String?

    /// UTM parameters from the link
    public let utmParameters: UTMParameters?

    /// Custom query parameters from the link
    public let customParameters: [String: String]?

    /// When the link was clicked (for attributed installs)
    public let clickedAt: Date?

    /// The link ID from the backend
    public let linkId: String?

    // MARK: - Initialization

    /// Creates deep link data
    public init(
        shortCode: String,
        iosURL: String? = nil,
        androidURL: String? = nil,
        webURL: String? = nil,
        utmParameters: UTMParameters? = nil,
        customParameters: [String: String]? = nil,
        clickedAt: Date? = nil,
        linkId: String? = nil
    ) {
        self.shortCode = shortCode
        self.iosURL = iosURL
        self.androidURL = androidURL
        self.webURL = webURL
        self.utmParameters = utmParameters
        self.customParameters = customParameters
        self.clickedAt = clickedAt
        self.linkId = linkId
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case shortCode
        case iosURL = "iosUrl"
        case androidURL = "androidUrl"
        case webURL = "webUrl"
        case utmParameters
        case customParameters
        case clickedAt
        case linkId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        shortCode = try container.decode(String.self, forKey: .shortCode)
        iosURL = try container.decodeIfPresent(String.self, forKey: .iosURL)
        androidURL = try container.decodeIfPresent(String.self, forKey: .androidURL)
        webURL = try container.decodeIfPresent(String.self, forKey: .webURL)
        utmParameters = try container.decodeIfPresent(UTMParameters.self, forKey: .utmParameters)
        customParameters = try container.decodeIfPresent([String: String].self, forKey: .customParameters)
        linkId = try container.decodeIfPresent(String.self, forKey: .linkId)

        // Decode date from ISO 8601 string
        if let dateString = try container.decodeIfPresent(String.self, forKey: .clickedAt) {
            let formatter = ISO8601DateFormatter()
            clickedAt = formatter.date(from: dateString)
        } else {
            clickedAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(shortCode, forKey: .shortCode)
        try container.encodeIfPresent(iosURL, forKey: .iosURL)
        try container.encodeIfPresent(androidURL, forKey: .androidURL)
        try container.encodeIfPresent(webURL, forKey: .webURL)
        try container.encodeIfPresent(utmParameters, forKey: .utmParameters)
        try container.encodeIfPresent(customParameters, forKey: .customParameters)
        try container.encodeIfPresent(linkId, forKey: .linkId)

        // Encode date as ISO 8601 string
        if let clickedAt = clickedAt {
            let formatter = ISO8601DateFormatter()
            try container.encode(formatter.string(from: clickedAt), forKey: .clickedAt)
        }
    }
}

// MARK: - CustomStringConvertible

extension DeepLinkData: CustomStringConvertible {
    public var description: String {
        """
        DeepLinkData(
            shortCode: \(shortCode),
            iosURL: \(iosURL ?? "nil"),
            linkId: \(linkId ?? "nil"),
            utmSource: \(utmParameters?.source ?? "nil")
        )
        """
    }
}
