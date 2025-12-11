//
//  LinkForty.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Main SDK class - singleton interface for LinkForty
@available(iOS 13.0, macOS 10.15, *)
public final class LinkForty {
    // MARK: - Singleton

    /// Shared instance
    public static let shared = LinkForty()

    // MARK: - Properties

    private var config: LinkFortyConfig?
    private var attributionManager: AttributionManager?
    private var eventTracker: EventTracker?
    private var deepLinkHandler: DeepLinkHandler?

    private let initQueue = DispatchQueue(label: "com.linkforty.sdk.init", qos: .userInitiated)
    private var isInitialized = false

    // MARK: - Initialization

    private init() {}

    /// Initializes the SDK with configuration
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - attributionWindowHours: Attribution window in hours (default: 168 = 7 days)
    ///   - deviceId: Optional device identifier for attribution
    /// - Returns: InstallResponse with attribution data
    /// - Throws: LinkFortyError if initialization fails
    @discardableResult
    public func initialize(
        config: LinkFortyConfig,
        attributionWindowHours: Int = 168,
        deviceId: String? = nil
    ) async throws -> InstallResponse {
        // Synchronize access to initialization state
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            initQueue.async {
                // Check if already initialized
                guard !self.isInitialized else {
                    continuation.resume(throwing: LinkFortyError.alreadyInitialized)
                    return
                }

                // Validate configuration
                do {
                    try config.validate()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Store configuration
                self.config = config

                // Create managers
                let storageManager = StorageManager()
                let networkManager = NetworkManager(config: config)
                let fingerprintCollector = FingerprintCollector()

                self.attributionManager = AttributionManager(
                    networkManager: networkManager,
                    storageManager: storageManager,
                    fingerprintCollector: fingerprintCollector
                )

                self.eventTracker = EventTracker(
                    networkManager: networkManager,
                    storageManager: storageManager
                )

                self.deepLinkHandler = DeepLinkHandler()

                // Mark as initialized
                self.isInitialized = true

                continuation.resume()
            }
        }

        // Report install and get attribution data (outside the serial queue)
        let response = try await attributionManager!.reportInstall(
            attributionWindowHours: attributionWindowHours,
            deviceId: deviceId
        )

        // If attributed, notify deferred deep link handler
        if response.attributed, let deepLinkData = response.deepLinkData {
            deepLinkHandler?.deliverDeferredDeepLink(deepLinkData)
        }

        LinkFortyLogger.log("SDK initialized successfully (attributed: \(response.attributed))")

        return response
    }

    // MARK: - Deep Linking

    /// Handles a deep link URL (Universal Link or custom scheme)
    /// - Parameter url: Deep link URL to handle
    public func handleDeepLink(url: URL) {
        guard isInitialized else {
            LinkFortyLogger.log("SDK not initialized. Call initialize() first.")
            return
        }

        deepLinkHandler?.handleDeepLink(url)
    }

    /// Registers a callback for deferred deep links (triggered on first launch after attributed install)
    /// - Parameter callback: Callback to invoke with deep link data
    public func onDeferredDeepLink(_ callback: @escaping DeferredDeepLinkCallback) {
        guard isInitialized else {
            LinkFortyLogger.log("SDK not initialized. Call initialize() first.")
            return
        }

        deepLinkHandler?.onDeferredDeepLink(callback)
    }

    /// Registers a callback for deep links (triggered when app opens from link)
    /// - Parameter callback: Callback to invoke with deep link data
    public func onDeepLink(_ callback: @escaping DeepLinkCallback) {
        guard isInitialized else {
            LinkFortyLogger.log("SDK not initialized. Call initialize() first.")
            return
        }

        deepLinkHandler?.onDeepLink(callback)
    }

    // MARK: - Event Tracking

    /// Tracks a custom event
    /// - Parameters:
    ///   - name: Event name (e.g., "purchase", "signup")
    ///   - properties: Optional event properties (must be JSON-serializable)
    /// - Throws: LinkFortyError if tracking fails
    public func trackEvent(name: String, properties: [String: Any]? = nil) async throws {
        guard isInitialized else {
            throw LinkFortyError.notInitialized
        }

        try await eventTracker?.trackEvent(name: name, properties: properties)
    }

    /// Tracks a revenue event
    /// - Parameters:
    ///   - amount: Revenue amount
    ///   - currency: Currency code (e.g., "USD")
    ///   - properties: Optional additional properties
    /// - Throws: LinkFortyError if tracking fails
    public func trackRevenue(
        amount: Decimal,
        currency: String,
        properties: [String: Any]? = nil
    ) async throws {
        guard isInitialized else {
            throw LinkFortyError.notInitialized
        }

        try await eventTracker?.trackRevenue(
            amount: amount,
            currency: currency,
            properties: properties
        )
    }

    /// Flushes the event queue, attempting to send all queued events
    public func flushEvents() async {
        guard isInitialized else {
            LinkFortyLogger.log("SDK not initialized. Call initialize() first.")
            return
        }

        await eventTracker?.flushQueue()
    }

    /// Returns the number of queued events
    public var queuedEventCount: Int {
        guard isInitialized else {
            return 0
        }

        return eventTracker?.queuedEventCount ?? 0
    }

    /// Clears the event queue
    public func clearEventQueue() {
        guard isInitialized else {
            LinkFortyLogger.log("SDK not initialized. Call initialize() first.")
            return
        }

        eventTracker?.clearQueue()
    }

    // MARK: - Attribution Data

    /// Returns the install ID if available
    public func getInstallId() -> String? {
        guard isInitialized else {
            return nil
        }

        return attributionManager?.getInstallId()
    }

    /// Returns the install attribution data if available
    public func getInstallData() -> DeepLinkData? {
        guard isInitialized else {
            return nil
        }

        return attributionManager?.getInstallData()
    }

    /// Returns whether this is the first launch
    public func isFirstLaunch() -> Bool {
        guard isInitialized else {
            return true
        }

        return attributionManager?.isFirstLaunch() ?? true
    }

    // MARK: - Data Management

    /// Clears all stored SDK data
    public func clearData() {
        attributionManager?.clearData()
        eventTracker?.clearQueue()
        deepLinkHandler?.clearCallbacks()

        LinkFortyLogger.log("All SDK data cleared")
    }

    /// Resets the SDK to uninitialized state
    /// Note: This does NOT clear stored data. Call clearData() first if needed.
    public func reset() {
        initQueue.sync {
            config = nil
            attributionManager = nil
            eventTracker = nil
            deepLinkHandler = nil
            isInitialized = false

            LinkFortyLogger.log("SDK reset to uninitialized state")
        }
    }
}
