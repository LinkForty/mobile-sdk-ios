//
//  LinkFortyConfig.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Configuration for the LinkForty SDK
public struct LinkFortyConfig {
    // MARK: - Properties

    /// The base URL of your LinkForty instance
    /// - Note: Must be HTTPS in production (HTTP allowed for localhost testing only)
    public let baseURL: URL

    /// API key for LinkForty Cloud (optional for self-hosted Core)
    /// - Note: Sent as Bearer token in Authorization header
    public let apiKey: String?

    /// Enable debug logging
    /// - Note: Logs network requests, responses, and SDK operations
    public let debug: Bool

    /// Attribution window in hours (1-2160, default: 168 = 7 days)
    /// - Note: How long after a click an install can be attributed
    public let attributionWindowHours: Int

    // MARK: - Initialization

    /// Creates a new LinkForty configuration
    ///
    /// - Parameters:
    ///   - baseURL: The base URL of your LinkForty instance (e.g., https://go.yourdomain.com)
    ///   - apiKey: Optional API key for LinkForty Cloud authentication
    ///   - debug: Enable debug logging (default: false)
    ///   - attributionWindowHours: Attribution window in hours (default: 168 = 7 days)
    ///
    /// - Note: For self-hosted LinkForty Core, omit the apiKey parameter
    public init(
        baseURL: URL,
        apiKey: String? = nil,
        debug: Bool = false,
        attributionWindowHours: Int = 168
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.debug = debug
        self.attributionWindowHours = attributionWindowHours
    }

    // MARK: - Validation

    /// Validates the configuration
    /// - Throws: `LinkFortyError.invalidConfiguration` if validation fails
    func validate() throws {
        // Validate HTTPS (except localhost)
        if baseURL.scheme != "https" && !isLocalhost {
            throw LinkFortyError.invalidConfiguration(
                "Base URL must use HTTPS (HTTP only allowed for localhost)"
            )
        }

        // Validate attribution window (1 hour to 90 days)
        guard attributionWindowHours >= 1 && attributionWindowHours <= 2160 else {
            throw LinkFortyError.invalidConfiguration(
                "Attribution window must be between 1 and 2160 hours"
            )
        }
    }

    // MARK: - Helpers

    /// Checks if the base URL is localhost
    private var isLocalhost: Bool {
        guard let host = baseURL.host else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0"
    }
}

// MARK: - CustomStringConvertible

extension LinkFortyConfig: CustomStringConvertible {
    public var description: String {
        """
        LinkFortyConfig(
            baseURL: \(baseURL.absoluteString),
            apiKey: \(apiKey != nil ? "***" : "nil"),
            debug: \(debug),
            attributionWindowHours: \(attributionWindowHours)
        )
        """
    }
}
