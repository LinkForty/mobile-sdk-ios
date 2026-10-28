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

    /// The LinkForty server the SDK talks to: `https://api.linkforty.com` on
    /// the hosted service, or your own server's URL
    /// - Note: Must be HTTPS in production (HTTP allowed for localhost testing only)
    public let baseURL: URL

    /// API key, needed only for `createLink(options:)`
    /// - Note: Sent as a Bearer token in the Authorization header when set.
    ///   It is a secret: leave it out unless the app creates links.
    public let apiKey: String?

    /// Your workspace's public app token
    /// - Note: Required on the hosted service: it matches installs only to
    ///   your workspace's links, puts organic installs (App Store discovery,
    ///   social mentions, etc.) in your workspace, and lets the SDK learn
    ///   your link domains. Find it in the dashboard under Workspace
    ///   Settings → App Token. A self-hosted Core server doesn't need it.
    ///   Safe to ship in your app bundle: it identifies the workspace only
    ///   and can't authenticate API actions.
    /// - Format: `at_<32 hex chars>`
    public let appToken: String?

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
    ///   - baseURL: The LinkForty server: `https://api.linkforty.com` on the hosted service, or your own server's URL
    ///   - apiKey: API key, needed only for `createLink(options:)`; a secret
    ///   - appToken: Your workspace's public app token; required on the hosted service
    ///   - debug: Enable debug logging (default: false)
    ///   - attributionWindowHours: Attribution window in hours (default: 168 = 7 days)
    ///
    /// - Note: For self-hosted LinkForty Core, omit `appToken`, and `apiKey` unless you use `createLink`
    public init(
        baseURL: URL,
        apiKey: String? = nil,
        appToken: String? = nil,
        debug: Bool = false,
        attributionWindowHours: Int = 168
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.appToken = appToken
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
            appToken: \(appToken != nil ? "***" : "nil"),
            debug: \(debug),
            attributionWindowHours: \(attributionWindowHours)
        )
        """
    }
}
