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
    private let eventQueue: EventQueue

    /// Background queue for event processing
    private let processingQueue = DispatchQueue(label: "com.linkforty.sdk.events", qos: .utility)

    // MARK: - Initialization

    /// Creates an event tracker
    /// - Parameters:
    ///   - networkManager: Network manager for API requests
    ///   - storageManager: Storage manager for install ID
    ///   - eventQueue: Event queue for offline support
    init(
        networkManager: NetworkManagerProtocol,
        storageManager: StorageManagerProtocol,
        eventQueue: EventQueue = EventQueue()
    ) {
        self.networkManager = networkManager
        self.storageManager = storageManager
        self.eventQueue = eventQueue
    }

    // MARK: - Event Tracking

    /// Tracks a custom event
    /// - Parameters:
    ///   - name: Event name (e.g., "purchase", "signup")
    ///   - properties: Optional event properties (must be JSON-serializable)
    /// - Throws: LinkFortyError if tracking fails
    func trackEvent(name: String, properties: [String: Any]? = nil) async throws {
        // Validate event name
        guard !name.isEmpty else {
            throw LinkFortyError.invalidEventData("Event name cannot be empty")
        }

        // Get install ID
        guard let installId = storageManager.getInstallId() else {
            throw LinkFortyError.notInitialized
        }

        // Create event request
        let event = EventRequest(
            installId: installId,
            eventName: name,
            eventData: properties ?? [:],
            timestamp: Date()
        )

        // Try to send immediately
        do {
            try await sendEvent(event)
            LinkFortyLogger.log("Event tracked: \(name)")

            // If send succeeds, try to flush queue
            await flushQueue()
        } catch {
            // If send fails, queue the event
            eventQueue.enqueue(event)
            LinkFortyLogger.log("Event queued due to error: \(error)")
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

    // MARK: - Queue Management

    /// Flushes the event queue, attempting to send all queued events
    func flushQueue() async {
        await processingQueue.sync { [weak self] in
            guard let self = self else { return }

            LinkFortyLogger.log("Flushing event queue (\(self.eventQueue.count) events)")

            while !self.eventQueue.isEmpty {
                guard let event = self.eventQueue.dequeue() else { break }

                Task {
                    do {
                        try await self.sendEvent(event)
                        LinkFortyLogger.log("Queued event sent: \(event.eventName)")
                    } catch {
                        // Re-queue if send fails
                        self.eventQueue.enqueue(event)
                        LinkFortyLogger.log("Failed to send queued event: \(error)")
                        return
                    }
                }
            }
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
