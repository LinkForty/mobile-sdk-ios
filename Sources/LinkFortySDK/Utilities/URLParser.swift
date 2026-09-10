//
//  URLParser.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Utility for parsing URLs and extracting parameters
struct URLParser {
    /// Extracts the short code from a URL path
    /// - Parameter url: The URL to parse
    /// - Returns: Short code if found, nil otherwise
    static func extractShortCode(from url: URL) -> String? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Short code is typically the last path component
        // e.g., https://go.example.com/abc123 -> "abc123"
        return pathComponents.last
    }

    /// Extracts UTM parameters from URL query
    /// - Parameter url: The URL to parse
    /// - Returns: UTM parameters if any are found, nil otherwise
    static func extractUTMParameters(from url: URL) -> UTMParameters? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        let utmSource = queryItems.first { $0.name == "utm_source" }?.value
        let utmMedium = queryItems.first { $0.name == "utm_medium" }?.value
        let utmCampaign = queryItems.first { $0.name == "utm_campaign" }?.value
        let utmTerm = queryItems.first { $0.name == "utm_term" }?.value
        let utmContent = queryItems.first { $0.name == "utm_content" }?.value

        // Only create UTM parameters if at least one is present
        guard utmSource != nil || utmMedium != nil || utmCampaign != nil ||
              utmTerm != nil || utmContent != nil else {
            return nil
        }

        return UTMParameters(
            source: utmSource,
            medium: utmMedium,
            campaign: utmCampaign,
            term: utmTerm,
            content: utmContent
        )
    }

    /// Extracts custom (non-UTM) query parameters from URL
    /// - Parameter url: The URL to parse
    /// - Returns: Dictionary of custom parameters, empty if none found
    /// Names LinkForty consumes; never a custom parameter. See the call site.
    static func isReservedParameter(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("utm_") || lower.hasPrefix("fp_") || lower == "lf_click"
    }

    static func extractCustomParameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }

        var customParams: [String: String] = [:]
        for item in queryItems {
            // Skip the names LinkForty consumes. Mirrors the server's own
            // filter so a direct open and a deferred install agree on what
            // reaches the app:
            //   utm_*    surfaced separately as utmParameters
            //   fp_*     fingerprint signals the SDK appends when resolving,
            //            which the redirect reads server-side for attribution
            //   lf_click the click id the redirect appends to a destination URL
            // A tapped short link would not normally carry the last two, but the
            // URL is public and anyone can append them.
            guard !Self.isReservedParameter(item.name),
                  let value = item.value else {
                continue
            }

            customParams[item.name] = value
        }

        return customParams
    }

    /// Parses a URL into DeepLinkData
    /// - Parameter url: The URL to parse
    /// - Returns: DeepLinkData with extracted information
    /// - Throws: LinkFortyError.invalidDeepLinkURL if URL is invalid
    static func parseDeepLink(from url: URL) -> DeepLinkData? {
        guard let shortCode = extractShortCode(from: url) else {
            return nil
        }

        let utmParameters = extractUTMParameters(from: url)
        let customParameters = extractCustomParameters(from: url)

        return DeepLinkData(
            shortCode: shortCode,
            iosURL: url.absoluteString,
            utmParameters: utmParameters,
            customParameters: customParameters.isEmpty ? nil : customParameters
        )
    }
}
