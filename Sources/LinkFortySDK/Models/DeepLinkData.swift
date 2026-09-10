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

    /// Deep link path for in-app routing (e.g., "/product/123")
    public let deepLinkPath: String?

    /// App URI scheme (e.g., "myapp")
    public let appScheme: String?

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
        deepLinkPath: String? = nil,
        appScheme: String? = nil,
        clickedAt: Date? = nil,
        linkId: String? = nil
    ) {
        self.shortCode = shortCode
        self.iosURL = iosURL
        self.androidURL = androidURL
        self.webURL = webURL
        self.utmParameters = utmParameters
        self.customParameters = customParameters
        self.deepLinkPath = deepLinkPath
        self.appScheme = appScheme
        self.clickedAt = clickedAt
        self.linkId = linkId
    }

    /// Returns a copy with the parameters carried on the opened URL merged in.
    ///
    /// Resolving a short code returns the link's *stored* configuration; the
    /// server has no way to know what was appended to the URL that was actually
    /// tapped. The SDK does, having just parsed it. Without this a link shared
    /// as `?slug=titanic` reaches the app with that value missing on a direct
    /// open, while the same link after a deferred install carries it — the
    /// server merges the click's parameters there.
    ///
    /// URL values win on a key collision, matching that server-side precedence:
    /// what a sharer put on the URL is more specific than the link's stored
    /// setup.
    ///
    /// Only `customParameters` is merged. `linkId`, `deepLinkPath`, `appScheme`,
    /// the store URLs and `utmParameters` are server truth that a local parse
    /// cannot know and must not overwrite.
    func mergingURLParameters(_ fromURL: [String: String]?) -> DeepLinkData {
        guard let fromURL = fromURL, !fromURL.isEmpty else { return self }

        var merged = customParameters ?? [:]
        for (key, value) in fromURL {
            merged[key] = value
        }

        return DeepLinkData(
            shortCode: shortCode,
            iosURL: iosURL,
            androidURL: androidURL,
            webURL: webURL,
            utmParameters: utmParameters,
            customParameters: merged,
            deepLinkPath: deepLinkPath,
            appScheme: appScheme,
            clickedAt: clickedAt,
            linkId: linkId
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case shortCode
        case iosURL = "iosUrl"
        case androidURL = "androidUrl"
        case webURL = "webUrl"
        case utmParameters
        case customParameters
        case deepLinkPath
        case appScheme
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
        deepLinkPath = try container.decodeIfPresent(String.self, forKey: .deepLinkPath)
        appScheme = try container.decodeIfPresent(String.self, forKey: .appScheme)
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
        try container.encodeIfPresent(deepLinkPath, forKey: .deepLinkPath)
        try container.encodeIfPresent(appScheme, forKey: .appScheme)
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
            deepLinkPath: \(deepLinkPath ?? "nil"),
            appScheme: \(appScheme ?? "nil"),
            linkId: \(linkId ?? "nil"),
            utmSource: \(utmParameters?.source ?? "nil")
        )
        """
    }
}
