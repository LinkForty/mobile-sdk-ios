//
//  CreateLinkOptions.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Options for creating a short link
public struct CreateLinkOptions: Encodable {
    /// Template ID (auto-selected if omitted)
    public let templateId: String?

    /// Template slug (only needed with templateId)
    public let templateSlug: String?

    /// Deep link parameters for in-app routing (e.g., ["route": "VIDEO_VIEWER", "id": "..."])
    public let deepLinkParameters: [String: String]?

    /// Link title
    public let title: String?

    /// Link description
    public let description: String?

    /// Custom short code (auto-generated if omitted)
    public let customCode: String?

    /// UTM parameters for campaign tracking
    public let utmParameters: UTMParameters?

    // MARK: - Initialization

    /// Creates link creation options
    public init(
        templateId: String? = nil,
        templateSlug: String? = nil,
        deepLinkParameters: [String: String]? = nil,
        title: String? = nil,
        description: String? = nil,
        customCode: String? = nil,
        utmParameters: UTMParameters? = nil
    ) {
        self.templateId = templateId
        self.templateSlug = templateSlug
        self.deepLinkParameters = deepLinkParameters
        self.title = title
        self.description = description
        self.customCode = customCode
        self.utmParameters = utmParameters
    }
}

/// Result of creating a short link
public struct CreateLinkResult: Decodable {
    /// Full shareable URL (e.g., "https://go.yourdomain.com/tmpl/abc123")
    public let url: String

    /// The generated short code
    public let shortCode: String

    /// Link UUID
    public let linkId: String
}

/// Response from the dashboard link creation endpoint (POST /api/links)
/// Maps the snake_case response to CreateLinkResult
struct DashboardCreateLinkResponse: Decodable {
    let id: String
    let shortCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case shortCode = "short_code"
    }
}
