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
    private var networkManager: NetworkManager?
    private var attributionManager: AttributionManager?
    private var attributionContext: AttributionContext?
    private var eventTracker: EventTracker?

    /// Created up front so callbacks registered before `initialize()` are kept;
    /// `initialize()` configures it.
    private var deepLinkHandler = DeepLinkHandler()

    /// Links handed to `handleDeepLink(url:)` before `initialize()`, as when a
    /// link cold-starts the app. Resolved once the SDK is configured.
    private var pendingDeepLinks: [URL] = []

    private var externalUserId: String?
    private let initQueue = DispatchQueue(label: "com.linkforty.sdk.init", qos: .userInitiated)
    private var isInitialized = false

    /// Whether this launch is the app's first, read from storage before the
    /// install is reported so it stays true for the whole launch.
    private var firstLaunchThisSession: Bool?

    /// Storage and session the managers are built with. Tests replace them.
    var userDefaults: UserDefaultsProtocol = UserDefaults.standard
    var urlSession: URLSessionProtocol = URLSession.shared

    // MARK: - Initialization

    private init() {}

    /// Initializes the SDK with configuration
    /// - Parameters:
    ///
    /// If the install can't be reported (for example, the device is offline),
    /// this throws and leaves the SDK uninitialized, so it can be called again.
    ///
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - attributionWindowHours: Attribution window in hours. Defaults to
    ///     `config.attributionWindowHours`.
    ///   - deviceId: Optional device identifier for attribution
    /// - Returns: InstallResponse with attribution data
    /// - Throws: LinkFortyError if initialization fails
    @discardableResult
    public func initialize(
        config: LinkFortyConfig,
        attributionWindowHours: Int? = nil,
        deviceId: String? = nil
    ) async throws -> InstallResponse {
        // Synchronize access to initialization state
        let pendingDeepLinks: [URL] = try await withCheckedThrowingContinuation { continuation in
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
                LinkFortyLogger.isDebugEnabled = config.debug

                // Create and wire the managers
                self.setUpManagers(config: config)

                // Mark as initialized
                self.isInitialized = true

                let pending = self.pendingDeepLinks
                self.pendingDeepLinks = []
                continuation.resume(returning: pending)
            }
        }

        _ = isFirstLaunch()

        let handler = initQueue.sync { deepLinkHandler }
        pendingDeepLinks.forEach { handler.handleDeepLink($0) }

        // Only the launch that reports the install delivers a deferred deep link;
        // later launches get the cached attribution without a callback.
        let isNewInstall = attributionManager!.getInstallId() == nil

        // Report install and get attribution data (outside the serial queue)
        let response: InstallResponse
        do {
            response = try await attributionManager!.reportInstall(
                attributionWindowHours: attributionWindowHours ?? config.attributionWindowHours,
                deviceId: deviceId,
                appToken: config.appToken
            )
        } catch {
            tearDownManagers()
            throw error
        }

        // The install's launch delivers its deep link, or nil for an organic install.
        if isNewInstall {
            handler.deliverDeferredDeepLink(response.attributed ? response.deepLinkData : nil)
        }

        LinkFortyLogger.log("SDK initialized successfully (attributed: \(response.attributed))")

        return response
    }

    /// Creates the SDK's managers and wires the shared attribution context into
    /// the event tracker and deep-link handler. Must be called on `initQueue`.
    private func setUpManagers(config: LinkFortyConfig) {
        let storageManager = StorageManager(userDefaults: userDefaults)
        let networkManager = NetworkManager(config: config, session: urlSession)
        let fingerprintCollector = FingerprintCollector()
        let attributionContext = AttributionContext(debug: config.debug)

        self.networkManager = networkManager
        self.attributionContext = attributionContext

        self.attributionManager = AttributionManager(
            networkManager: networkManager,
            storageManager: storageManager,
            fingerprintCollector: fingerprintCollector
        )

        self.eventTracker = EventTracker(
            networkManager: networkManager,
            storageManager: storageManager,
            attributionContext: attributionContext
        )

        deepLinkHandler.configure(
            networkManager: networkManager,
            fingerprintCollector: fingerprintCollector,
            baseURL: config.baseURL,
            attributionContext: attributionContext
        )
    }

    /// Returns the SDK to its uninitialized state after a failed install report,
    /// keeping registered callbacks, so `initialize()` can be called again.
    private func tearDownManagers() {
        initQueue.sync {
            config = nil
            networkManager = nil
            attributionManager = nil
            attributionContext = nil
            eventTracker = nil
            isInitialized = false
        }
    }

    // MARK: - Deep Linking

    /// Handles a deep link URL (Universal Link or custom scheme)
    ///
    /// A link handed over before `initialize()`, as when it cold-starts the app,
    /// is held and resolved once `initialize()` configures the SDK.
    /// - Parameter url: Deep link URL to handle
    public func handleDeepLink(url: URL) {
        let handler: DeepLinkHandler? = initQueue.sync {
            guard isInitialized else {
                pendingDeepLinks.append(url)
                return nil
            }
            return deepLinkHandler
        }

        guard let handler else {
            LinkFortyLogger.log("Deep link held until initialize(): \(url.absoluteString)")
            return
        }
        handler.handleDeepLink(url)
    }

    /// Registers a callback for deferred deep links, called once on the launch
    /// that reports the install: with the link's data, or nil for an organic install.
    /// Can be registered before or after `initialize()`.
    /// - Parameter callback: Callback to invoke with deep link data
    public func onDeferredDeepLink(_ callback: @escaping DeferredDeepLinkCallback) {
        initQueue.sync { deepLinkHandler }.onDeferredDeepLink(callback)
    }

    /// Registers a callback for deep links (triggered when app opens from link).
    /// Can be registered before or after `initialize()`.
    /// - Parameter callback: Callback to invoke with deep link data
    public func onDeepLink(_ callback: @escaping DeepLinkCallback) {
        initQueue.sync { deepLinkHandler }.onDeepLink(callback)
    }

    // MARK: - User Identity

    /// Sets the external user ID for attribution. This ID will be attached to all
    /// links created via `createLink()` unless overridden per-call. Pass `nil` to clear.
    /// - Parameter id: External user ID string, or nil to clear
    public func setExternalUserId(_ id: String?) {
        self.externalUserId = id
        LinkFortyLogger.log("External user ID set: \(id ?? "nil")")
    }

    /// Returns the current external user ID, if set
    public func getExternalUserId() -> String? {
        externalUserId
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

    /// Tracks a screen view.
    ///
    /// Emits a `screen_view` event stamped with the active last-click attribution
    /// context, so the dashboard can show which screens users reach after opening a
    /// deep link. Call from `viewDidAppear` (UIKit) or use the SwiftUI
    /// `.linkfortyScreen("Name")` modifier.
    ///
    /// - Parameters:
    ///   - name: Screen name (e.g., "ProductDetail")
    ///   - properties: Optional additional properties
    /// - Throws: LinkFortyError if tracking fails
    public func trackScreenView(name: String, properties: [String: Any]? = nil) async throws {
        guard isInitialized else {
            throw LinkFortyError.notInitialized
        }

        try await eventTracker?.trackScreenView(name: name, properties: properties)
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

    // MARK: - Link Creation

    /// Creates a short link programmatically
    ///
    /// - Parameter options: Link creation options
    /// - Returns: Result containing the shareable URL, short code, and link ID
    /// - Throws: `LinkFortyError.notInitialized` if SDK not initialized,
    ///           `LinkFortyError.missingApiKey` if no API key configured
    ///
    /// - Note: Requires an API key in `LinkFortyConfig`. Posts to the SDK link
    ///   endpoint (`POST /api/sdk/v1/links`), which records the external user ID
    ///   and uses `templateId` when given, or the workspace's default template.
    ///   A server without that endpoint (404) gets the request on `POST /api/links`.
    public func createLink(options: CreateLinkOptions) async throws -> CreateLinkResult {
        guard isInitialized else {
            throw LinkFortyError.notInitialized
        }

        guard let config = config, config.apiKey != nil else {
            throw LinkFortyError.missingApiKey
        }

        guard let networkManager = networkManager else {
            throw LinkFortyError.notInitialized
        }

        // Per-call externalUserId takes precedence, then fall back to SDK-level value
        let resolvedOptions: CreateLinkOptions
        if options.externalUserId == nil, let sdkUserId = externalUserId {
            resolvedOptions = CreateLinkOptions(
                templateId: options.templateId,
                templateSlug: options.templateSlug,
                deepLinkParameters: options.deepLinkParameters,
                title: options.title,
                description: options.description,
                customCode: options.customCode,
                utmParameters: options.utmParameters,
                externalUserId: sdkUserId
            )
        } else {
            resolvedOptions = options
        }

        do {
            return try await networkManager.request(
                endpoint: "/api/sdk/v1/links",
                method: .post,
                body: resolvedOptions
            )
        } catch LinkFortyError.invalidResponse(statusCode: 404, _) {
            LinkFortyLogger.log("No SDK link endpoint on this server; creating the link with /api/links")
        }

        let response: DashboardCreateLinkResponse = try await networkManager.request(
            endpoint: "/api/links",
            method: .post,
            body: resolvedOptions
        )

        // The server's short URL carries the link's own domain; older
        // servers don't return one, so fall back to building it.
        let templateSlug = resolvedOptions.templateSlug ?? ""
        let pathSegment = templateSlug.isEmpty ? response.shortCode : "\(templateSlug)/\(response.shortCode)"
        let url = response.shortUrl ?? config.baseURL.appendingPathComponent(pathSegment).absoluteString

        return CreateLinkResult(
            url: url,
            shortCode: response.shortCode,
            linkId: response.id,
            deduplicated: nil
        )
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

    /// Returns whether this is the app's first launch since installation
    ///
    /// Usable before `initialize()`, and stays true for the whole first launch:
    /// the value is read from storage once per launch, before the install is
    /// reported.
    public func isFirstLaunch() -> Bool {
        initQueue.sync {
            if let firstLaunch = firstLaunchThisSession {
                return firstLaunch
            }

            let firstLaunch = StorageManager(userDefaults: userDefaults).isFirstLaunch()
            firstLaunchThisSession = firstLaunch
            return firstLaunch
        }
    }

    // MARK: - Data Management

    /// Clears all stored SDK data. Registered callbacks are kept.
    public func clearData() {
        attributionManager?.clearData()
        attributionContext?.clear()
        eventTracker?.clearQueue()
        initQueue.sync { deepLinkHandler }.clearDeferredDeepLink()
        externalUserId = nil
        initQueue.sync { firstLaunchThisSession = nil }

        LinkFortyLogger.log("All SDK data cleared")
    }

    /// Resets the SDK to uninitialized state
    /// Note: This does NOT clear stored data. Call clearData() first if needed.
    public func reset() {
        initQueue.sync {
            config = nil
            networkManager = nil
            attributionManager = nil
            attributionContext = nil
            eventTracker = nil
            deepLinkHandler = DeepLinkHandler()
            pendingDeepLinks = []
            externalUserId = nil
            isInitialized = false
            firstLaunchThisSession = nil

            LinkFortyLogger.log("SDK reset to uninitialized state")
        }
    }
}
