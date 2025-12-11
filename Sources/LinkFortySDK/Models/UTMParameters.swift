//
//  UTMParameters.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// UTM parameters for campaign tracking
public struct UTMParameters: Codable, Equatable {
    /// Campaign source (e.g., "google", "facebook", "email")
    public let source: String?

    /// Campaign medium (e.g., "cpc", "banner", "email")
    public let medium: String?

    /// Campaign name (e.g., "summer_sale", "product_launch")
    public let campaign: String?

    /// Campaign term (e.g., "running+shoes")
    public let term: String?

    /// Campaign content (e.g., "logolink", "textlink")
    public let content: String?

    // MARK: - Initialization

    /// Creates UTM parameters
    public init(
        source: String? = nil,
        medium: String? = nil,
        campaign: String? = nil,
        term: String? = nil,
        content: String? = nil
    ) {
        self.source = source
        self.medium = medium
        self.campaign = campaign
        self.term = term
        self.content = content
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case source
        case medium
        case campaign
        case term
        case content
    }

    // MARK: - Helpers

    /// Checks if any UTM parameter is set
    public var hasAnyParameter: Bool {
        source != nil || medium != nil || campaign != nil || term != nil || content != nil
    }
}

// MARK: - CustomStringConvertible

extension UTMParameters: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        if let source = source { parts.append("source=\(source)") }
        if let medium = medium { parts.append("medium=\(medium)") }
        if let campaign = campaign { parts.append("campaign=\(campaign)") }
        if let term = term { parts.append("term=\(term)") }
        if let content = content { parts.append("content=\(content)") }
        return "UTMParameters(\(parts.joined(separator: ", ")))"
    }
}
