//
//  EventTracker.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Tracks custom events and manages event queueing
@available(iOS 13.0, macOS 10.15, *)
final class EventTracker {
    // MARK: - Properties

    private let networkManager: NetworkManagerProtocol
    private let storageManager: StorageManagerProtocol
    private let attributionContext: AttributionContext
    private let eventQueue: EventQueue

    /// Guards `lastScreenName` for the `previousScreen` transition stamp.
    private let screenLock = NSLock()
    private var lastScreenName: String?

    /// Guards `isFlushing`, so a flush started while one runs returns at once.
    private let flushLock = NSLock()
    private var isFlushing = false

    // MARK: - Initialization

    /// Creates an event tracker
    /// - Parameters:
    ///   - networkManager: Network manager for API requests
    ///   - storageManager: Storage manager for install ID
    ///   - attributionContext: Last-click attribution context stamped onto each event
    ///   - eventQueue: Event queue for offline support
    init(
        networkManager: NetworkManagerProtocol,
        storageManager: StorageManagerProtocol,
        attributionContext: AttributionContext,
        eventQueue: EventQueue = EventQueue()
    ) {
        self.networkManager = networkManager
        self.storageManager = storageManager
        self.attributionContext = attributionContext
        self.eventQueue = eventQueue
    }

    // MARK: - Event Tracking

    /// Tracks a custom event
    ///
    /// An event that can't be sent now (no connection, or a server error) is
    /// queued on the device and sent later, and the call returns normally.
    /// - Parameters:
    ///   - name: Event name (e.g., "purchase", "signup")
    ///   - properties: Optional event properties (must be JSON-serializable)
    /// - Throws: LinkFortyError for an invalid event, or one the server rejects
    func trackEvent(name: String, properties: [String: Any]? = nil) async throws {
        // Validate event name
        guard !name.isEmpty else {
            throw LinkFortyError.invalidEventData("Event name cannot be empty")
        }

        // Get install ID
        guard let installId = storageManager.getInstallId() else {
            throw LinkFortyError.notInitialized
        }

        // Stamp the event with the active last-click attribution context so the
        // backend can credit the deep link that drove it (organic events carry
        // only the session id).
        let stamp = attributionContext.getStamp()
        let event = EventRequest(
            installId: installId,
            eventName: name,
            eventData: properties ?? [:],
            timestamp: Date(),
            attributedLinkId: stamp.attributedLinkId,
            attributedClickId: stamp.attributedClickId,
            linkOpenedAt: stamp.linkOpenedAt,
            sessionId: stamp.sessionId
        )

        // Stored before it is sent, so the event survives the app closing
        // mid-send; a flush that sends it too is answered as a repeat.
        let stored = eventQueue.enqueue(event)
        do {
            try await sendEvent(event)
            eventQueue.remove(event)
            LinkFortyLogger.log("Event tracked: \(name)")

            // If send succeeds, try to flush queue
            await flushQueue()
        } catch where Self.isRetryable(error) {
            // A later attempt can succeed: it stays on the device and is sent then.
            LinkFortyLogger.log(stored
                ? "Event queued due to error: \(error)"
                : "Event queue full, event not kept: \(error)")
        } catch {
            eventQueue.remove(event)
            throw error
        }
    }

    /// Tracks a revenue event
    /// - Parameters:
    ///   - amount: Revenue amount
    ///   - currency: Currency code (e.g., "USD")
    ///   - properties: Optional additional properties
    /// - Throws: LinkFortyError if tracking fails
    func trackRevenue(
        amount: Decimal,
        currency: String,
        properties: [String: Any]? = nil
    ) async throws {
        guard amount >= 0 else {
            throw LinkFortyError.invalidEventData("Revenue amount must be non-negative")
        }

        var eventProperties = properties ?? [:]
        eventProperties["revenue"] = NSDecimalNumber(decimal: amount).doubleValue
        eventProperties["currency"] = currency

        try await trackEvent(name: "revenue", properties: eventProperties)
    }

    /// Tracks a screen view.
    ///
    /// Emits a `screen_view` event (through the normal event pipeline, so it is
    /// stamped with the active last-click attribution context) carrying the screen
    /// name and — when available — the previously tracked screen, so the dashboard
    /// can build a per-link screen-flow funnel.
    ///
    /// - Parameters:
    ///   - name: Screen name (e.g., "ProductDetail")
    ///   - properties: Optional additional properties
    /// - Throws: LinkFortyError if tracking fails
    func trackScreenView(name: String, properties: [String: Any]? = nil) async throws {
        guard !name.isEmpty else {
            throw LinkFortyError.invalidEventData("Screen name cannot be empty")
        }

        let previous = swapLastScreen(to: name)

        var eventProperties = properties ?? [:]
        eventProperties["screen"] = name
        if let previous = previous, previous != name {
            eventProperties["previousScreen"] = previous
        }

        try await trackEvent(name: "screen_view", properties: eventProperties)
    }

    /// Atomically records the current screen and returns the previous one.
    /// Kept synchronous so the lock never spans an `await`.
    private func swapLastScreen(to name: String) -> String? {
        screenLock.lock()
        defer { screenLock.unlock() }
        let previous = lastScreenName
        lastScreenName = name
        return previous
    }

    // MARK: - Queue Management

    /// Sends queued events in order and returns when they are sent. An event
    /// leaves the queue once the server has it, or has rejected it; the first
    /// one that fails with an error worth retrying stays at the head and stops
    /// the flush. A flush started while another runs returns at once: the
    /// running flush sends everything queued.
    func flushQueue() async {
        guard beginFlush() else { return }
        defer { endFlush() }

        if !eventQueue.isEmpty {
            LinkFortyLogger.log("Flushing event queue (\(eventQueue.count) events)")
        }

        while let event = eventQueue.first() {
            do {
                try await sendEvent(event)
                eventQueue.removeFirst(event)
                LinkFortyLogger.log("Queued event sent: \(event.eventName)")
            } catch where Self.isRetryable(error) {
                LinkFortyLogger.log("Failed to send queued event, keeping it queued: \(error)")
                return
            } catch {
                eventQueue.removeFirst(event)
                LinkFortyLogger.log("Dropping queued event the server rejected: \(error)")
            }
        }
    }

    private func beginFlush() -> Bool {
        flushLock.lock()
        defer { flushLock.unlock() }
        guard !isFlushing else { return false }
        isFlushing = true
        return true
    }

    private func endFlush() {
        flushLock.lock()
        isFlushing = false
        flushLock.unlock()
    }

    /// Network failures and server errors (5xx) can succeed later; anything else
    /// (a 4xx, an event that can't be encoded) will fail the same way again.
    static func isRetryable(_ error: Error) -> Bool {
        switch error {
        case LinkFortyError.networkError:
            return true
        case LinkFortyError.invalidResponse(let statusCode, _):
            return statusCode.map { $0 >= 500 } ?? true
        default:
            return false
        }
    }

    /// Returns the number of queued events
    var queuedEventCount: Int {
        eventQueue.count
    }

    /// Clears the event queue
    func clearQueue() {
        eventQueue.clear()
    }

    // MARK: - Private Helpers

    /// Sends an event to the backend
    /// - Parameter event: Event to send
    /// - Throws: LinkFortyError on failure
    private func sendEvent(_ event: EventRequest) async throws {
        let _: EventResponse = try await networkManager.request(
            endpoint: "/api/sdk/v1/event",
            method: .post,
            body: event,
            headers: nil
        )
    }
}
