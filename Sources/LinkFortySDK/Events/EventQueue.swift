//
//  EventQueue.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Events waiting to be sent, oldest first, at most 100.
///
/// With a store, the queue is saved after every change and restored when it is
/// created, so events still waiting when the app is closed are sent on a later
/// launch. An event leaves the queue only once it has been sent (see
/// `EventTracker.flushQueue()`), so a flush cut short by the app closing loses
/// nothing.
class EventQueue {
    // MARK: - Properties

    private let maxQueueSize = 100

    private var queue: [EventRequest] = []

    private let accessQueue = DispatchQueue(label: "com.linkforty.sdk.eventqueue", qos: .utility)

    private let store: UserDefaultsProtocol?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    /// - Parameter store: Where the queue is saved; `nil` keeps it in memory only.
    init(store: UserDefaultsProtocol? = nil) {
        self.store = store
        guard let data = store?.data(forKey: StorageKeys.eventQueue) else { return }
        do {
            queue = Array(try decoder.decode([EventRequest].self, from: data).prefix(maxQueueSize))
            if !queue.isEmpty {
                LinkFortyLogger.log("Restored \(queue.count) queued event(s)")
            }
        } catch {
            LinkFortyLogger.log("Discarding unreadable event queue: \(error)")
            store?.removeObject(forKey: StorageKeys.eventQueue)
        }
    }

    // MARK: - Queue Management

    @discardableResult
    func enqueue(_ event: EventRequest) -> Bool {
        accessQueue.sync {
            guard queue.count < maxQueueSize else {
                LinkFortyLogger.log("Event queue full, dropping event: \(event.eventName)")
                return false
            }

            queue.append(event)
            save()
            LinkFortyLogger.log("Event queued: \(event.eventName) (queue size: \(queue.count))")
            return true
        }
    }

    /// The oldest event, left in the queue.
    func first() -> EventRequest? {
        accessQueue.sync { queue.first }
    }

    /// Removes the oldest event if it is `event`, once it has been sent or rejected.
    func removeFirst(_ event: EventRequest) {
        accessQueue.sync {
            guard queue.first?.clientEventId == event.clientEventId else { return }
            queue.removeFirst()
            save()
        }
    }

    /// Removes `event` wherever it is in the queue.
    func remove(_ event: EventRequest) {
        accessQueue.sync {
            guard let index = queue.firstIndex(where: { $0.clientEventId == event.clientEventId }) else { return }
            queue.remove(at: index)
            save()
        }
    }

    func dequeue() -> EventRequest? {
        accessQueue.sync {
            guard !queue.isEmpty else { return nil }
            let event = queue.removeFirst()
            save()
            return event
        }
    }

    func peek() -> [EventRequest] {
        accessQueue.sync {
            Array(queue)
        }
    }

    func clear() {
        accessQueue.sync {
            let count = queue.count
            queue.removeAll()
            save()
            if count > 0 {
                LinkFortyLogger.log("Event queue cleared (\(count) events removed)")
            }
        }
    }

    var count: Int {
        accessQueue.sync {
            queue.count
        }
    }

    var isEmpty: Bool {
        accessQueue.sync {
            queue.isEmpty
        }
    }

    var isFull: Bool {
        accessQueue.sync {
            queue.count >= maxQueueSize
        }
    }

    // MARK: - Private

    /// Writes the queue to the store. Must be called on `accessQueue`.
    private func save() {
        guard let store else { return }
        if queue.isEmpty {
            store.removeObject(forKey: StorageKeys.eventQueue)
            return
        }
        do {
            store.set(try encoder.encode(queue), forKey: StorageKeys.eventQueue)
        } catch {
            LinkFortyLogger.log("Failed to save event queue: \(error)")
        }
    }
}
