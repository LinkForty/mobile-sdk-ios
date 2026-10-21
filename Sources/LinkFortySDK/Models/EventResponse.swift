//
//  EventResponse.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Response from the event tracking endpoint. A 2xx status means the event was
/// stored; the fields are informational.
struct EventResponse: Codable {
    /// Server-assigned event ID
    let eventId: String?

    /// Whether the server accepted the event
    let acknowledged: Bool?

    init(eventId: String? = nil, acknowledged: Bool? = true) {
        self.eventId = eventId
        self.acknowledged = acknowledged
    }
}
