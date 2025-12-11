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
final class DeepLinkHandler {
    // MARK: - Properties

    private var deferredDeepLinkCallbacks: [DeferredDeepLinkCallback] = []
    private var deepLinkCallbacks: [DeepLinkCallback] = []

    /// Queue for thread-safe callback management
    private let queue = DispatchQueue(label: "com.linkforty.sdk.deeplink", qos: .userInitiated)

    /// Flag to track if deferred deep link has been delivered
    private var deferredDeepLinkDelivered = false

    /// Cached deferred deep link data
    private var cachedDeferredDeepLink: DeepLinkData?

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

    /// Handles a deep link URL
    /// - Parameter url: The URL that opened the app
    func handleDeepLink(_ url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }

            LinkFortyLogger.log("Handling deep link: \(url.absoluteString)")

            // Parse the URL
            let deepLinkData = URLParser.parseDeepLink(from: url)

            if let data = deepLinkData {
                LinkFortyLogger.log("Parsed deep link: \(data)")
            } else {
                LinkFortyLogger.log("Failed to parse deep link URL")
            }

            // Invoke all callbacks on main thread
            let callbacks = self.deepLinkCallbacks
            DispatchQueue.main.async {
                callbacks.forEach { $0(url, deepLinkData) }
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
}
