//
//  DeepLinkHandler.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Callback for deferred deep links (install attribution)
/// - Parameter deepLinkData: Deep link data if attributed, nil for organic installs
public typealias DeferredDeepLinkCallback = (DeepLinkData?) -> Void

/// Callback for direct deep links (Universal Links, custom schemes)
/// - Parameters:
///   - url: The URL that opened the app
///   - deepLinkData: Parsed deep link data, nil if parsing failed
public typealias DeepLinkCallback = (URL, DeepLinkData?) -> Void

/// Handles deep linking and callbacks
@available(iOS 13.0, macOS 10.15, *)
final class DeepLinkHandler {
    // MARK: - Properties

    private var deferredDeepLinkCallbacks: [DeferredDeepLinkCallback] = []
    private var deepLinkCallbacks: [DeepLinkCallback] = []

    /// Network manager for server-side URL resolution
    private var networkManager: NetworkManagerProtocol?

    /// Fingerprint collector for resolution requests
    private var fingerprintCollector: FingerprintCollectorProtocol?

    /// Base URL for detecting LinkForty URLs
    private var baseURL: URL?

    /// Queue for thread-safe callback management
    private let queue = DispatchQueue(label: "com.linkforty.sdk.deeplink", qos: .userInitiated)

    /// Flag to track if deferred deep link has been delivered
    private var deferredDeepLinkDelivered = false

    /// Cached deferred deep link data
    private var cachedDeferredDeepLink: DeepLinkData?

    // MARK: - Configuration

    /// Configures the handler with network capabilities for server-side resolution
    /// - Parameters:
    ///   - networkManager: Network manager for API requests
    ///   - fingerprintCollector: Fingerprint collector for resolution requests
    ///   - baseURL: Base URL for detecting LinkForty URLs
    func configure(
        networkManager: NetworkManagerProtocol,
        fingerprintCollector: FingerprintCollectorProtocol,
        baseURL: URL
    ) {
        self.networkManager = networkManager
        self.fingerprintCollector = fingerprintCollector
        self.baseURL = baseURL
    }

    // MARK: - Deferred Deep Link (Install Attribution)

    /// Registers a callback for deferred deep links
    /// - Parameter callback: Callback to invoke when deferred deep link data is available
    /// - Note: If data is already cached, callback is invoked immediately
    func onDeferredDeepLink(_ callback: @escaping DeferredDeepLinkCallback) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Add callback to list
            self.deferredDeepLinkCallbacks.append(callback)

            // If we already have data, invoke immediately on main thread
            if self.deferredDeepLinkDelivered {
                DispatchQueue.main.async {
                    callback(self.cachedDeferredDeepLink)
                }
            }
        }
    }

    /// Delivers deferred deep link data to all registered callbacks
    /// - Parameter deepLinkData: Deep link data from attribution, nil for organic
    func deliverDeferredDeepLink(_ deepLinkData: DeepLinkData?) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Cache the data
            self.cachedDeferredDeepLink = deepLinkData
            self.deferredDeepLinkDelivered = true

            LinkFortyLogger.log("Delivering deferred deep link: \(deepLinkData?.shortCode ?? "organic")")

            // Invoke all callbacks on main thread
            let callbacks = self.deferredDeepLinkCallbacks
            DispatchQueue.main.async {
                callbacks.forEach { $0(deepLinkData) }
            }
        }
    }

    // MARK: - Direct Deep Link (Universal Links, Custom Schemes)

    /// Registers a callback for direct deep links
    /// - Parameter callback: Callback to invoke when app is opened via deep link
    func onDeepLink(_ callback: @escaping DeepLinkCallback) {
        queue.async { [weak self] in
            self?.deepLinkCallbacks.append(callback)
        }
    }

    /// Handles a deep link URL with server-side resolution
    /// - Parameter url: The URL that opened the app
    func handleDeepLink(_ url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }

            LinkFortyLogger.log("Handling deep link: \(url.absoluteString)")

            // Parse locally first as fallback
            let localData = URLParser.parseDeepLink(from: url)

            // Attempt server-side resolution if configured
            if self.networkManager != nil && self.fingerprintCollector != nil {
                Task {
                    let resolvedData = await self.resolveURL(url, fallback: localData)
                    self.deliverDeepLink(url: url, data: resolvedData)
                }
            } else {
                // No network manager — use local parsing only
                self.deliverDeepLink(url: url, data: localData)
            }
        }
    }

    // MARK: - Testing Helpers

    /// Clears all registered callbacks (for testing)
    func clearCallbacks() {
        queue.async { [weak self] in
            self?.deferredDeepLinkCallbacks.removeAll()
            self?.deepLinkCallbacks.removeAll()
            self?.deferredDeepLinkDelivered = false
            self?.cachedDeferredDeepLink = nil
        }
    }

    // MARK: - Private Methods

    /// Resolves a URL via the server, falling back to local data on failure
    private func resolveURL(_ url: URL, fallback: DeepLinkData?) async -> DeepLinkData? {
        guard let networkManager = networkManager,
              let fingerprintCollector = fingerprintCollector else {
            return fallback
        }

        // Extract path segments
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard !pathComponents.isEmpty else { return fallback }

        // Build resolve path: /api/sdk/v1/resolve/{templateSlug?}/{shortCode}
        let resolvePath: String
        if pathComponents.count >= 2 {
            let templateSlug = pathComponents[pathComponents.count - 2]
            let shortCode = pathComponents[pathComponents.count - 1]
            resolvePath = "/api/sdk/v1/resolve/\(templateSlug)/\(shortCode)"
        } else {
            let shortCode = pathComponents[0]
            resolvePath = "/api/sdk/v1/resolve/\(shortCode)"
        }

        // Collect fingerprint for query parameters
        let fingerprint = fingerprintCollector.collectFingerprint(
            attributionWindowHours: 168,
            deviceId: nil
        )

        // Build query string
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fp_tz", value: fingerprint.timezone),
            URLQueryItem(name: "fp_lang", value: fingerprint.language),
            URLQueryItem(name: "fp_sw", value: String(fingerprint.screenWidth)),
            URLQueryItem(name: "fp_sh", value: String(fingerprint.screenHeight)),
            URLQueryItem(name: "fp_platform", value: fingerprint.platform),
            URLQueryItem(name: "fp_pv", value: fingerprint.platformVersion),
        ]

        var components = URLComponents()
        components.queryItems = queryItems
        let queryString = components.percentEncodedQuery ?? ""
        let endpoint = "\(resolvePath)?\(queryString)"

        do {
            let resolved: DeepLinkData = try await networkManager.request(
                endpoint: endpoint,
                method: .get,
                body: nil,
                headers: nil
            )
            LinkFortyLogger.log("Server-side resolution succeeded for \(url.absoluteString)")
            return resolved
        } catch {
            LinkFortyLogger.log("Server-side resolution failed, using local parse: \(error.localizedDescription)")
            return fallback
        }
    }

    /// Delivers deep link data to all registered callbacks on the main thread
    private func deliverDeepLink(url: URL, data: DeepLinkData?) {
        if let data = data {
            LinkFortyLogger.log("Parsed deep link: \(data)")
        } else {
            LinkFortyLogger.log("Failed to parse deep link URL")
        }

        let callbacks = self.deepLinkCallbacks
        DispatchQueue.main.async {
            callbacks.forEach { $0(url, data) }
        }
    }
}
