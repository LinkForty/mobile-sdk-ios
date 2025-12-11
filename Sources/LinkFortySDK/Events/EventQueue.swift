//
//  EventQueue.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Queue for storing events when offline
class EventQueue {
    // MARK: - Properties

    /// Maximum number of events to queue
    private let maxQueueSize = 100

    /// Queued events
    private var queue: [EventRequest] = []

    /// Serial queue for thread-safe operations
    private let accessQueue = DispatchQueue(label: "com.linkforty.sdk.eventqueue", qos: .utility)

    // MARK: - Queue Management

    /// Adds an event to the queue
    /// - Parameter event: Event to queue
    /// - Returns: True if added, false if queue is full
    @discardableResult
    func enqueue(_ event: EventRequest) -> Bool {
        accessQueue.sync {
            guard queue.count < maxQueueSize else {
                LinkFortyLogger.log("Event queue full, dropping event: \(event.eventName)")
                return false
            }

            queue.append(event)
            LinkFortyLogger.log("Event queued: \(event.eventName) (queue size: \(queue.count))")
            return true
        }
    }

    /// Dequeues the oldest event
    /// - Returns: The oldest event, or nil if queue is empty
    func dequeue() -> EventRequest? {
        accessQueue.sync {
            guard !queue.isEmpty else { return nil }
            return queue.removeFirst()
        }
    }

    /// Returns all queued events without removing them
    /// - Returns: Array of queued events
    func peek() -> [EventRequest] {
        accessQueue.sync {
            Array(queue)
        }
    }

    /// Clears all events from the queue
    func clear() {
        accessQueue.sync {
            let count = queue.count
            queue.removeAll()
            if count > 0 {
                LinkFortyLogger.log("Event queue cleared (\(count) events removed)")
            }
        }
    }

    /// Returns the number of queued events
    var count: Int {
        accessQueue.sync {
            queue.count
        }
    }

    /// Checks if the queue is empty
    var isEmpty: Bool {
        accessQueue.sync {
            queue.isEmpty
        }
    }

    /// Checks if the queue is full
    var isFull: Bool {
        accessQueue.sync {
            queue.count >= maxQueueSize
        }
    }
}
