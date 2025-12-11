//
//  EventResponse.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Response from event tracking endpoint
struct EventResponse: Codable {
    /// Whether the event was successfully tracked
    let success: Bool
}
