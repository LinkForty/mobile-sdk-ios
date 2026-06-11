//
//  EventRequest.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Request payload for tracking events
struct EventRequest: Codable {
    /// The install ID from attribution
    let installId: String

    /// Name of the event (e.g., "purchase", "signup")
    let eventName: String

    /// Custom event properties (must be JSON-serializable)
    let eventData: [String: AnyCodable]

    /// ISO 8601 timestamp of when the event occurred
    let timestamp: String

    /// SDK platform identifier (e.g., "ios"), for backend SDK diagnostics
    let sdkName: String

    /// SDK release version (e.g., "1.4.0"), for backend SDK diagnostics
    let sdkVersion: String

    // MARK: - Last-click attribution stamp (SIT-237)

    /// The deep link currently credited for this event (last-click). Absent for
    /// organic activity (no deep link has opened the app).
    let attributedLinkId: String?

    /// The originating click id, when known.
    let attributedClickId: String?

    /// ISO 8601 timestamp of when the attributing deep link opened the app.
    let linkOpenedAt: String?

    /// The app-open session this event belongs to (for screen-flow grouping).
    let sessionId: String?

    // MARK: - Initialization

    init(
        installId: String,
        eventName: String,
        eventData: [String: Any],
        timestamp: Date = Date(),
        attributedLinkId: String? = nil,
        attributedClickId: String? = nil,
        linkOpenedAt: String? = nil,
        sessionId: String? = nil
    ) {
        self.installId = installId
        self.eventName = eventName
        self.eventData = eventData.mapValues { AnyCodable($0) }

        let formatter = ISO8601DateFormatter()
        self.timestamp = formatter.string(from: timestamp)

        self.sdkName = SDKInfo.name
        self.sdkVersion = SDKInfo.version

        self.attributedLinkId = attributedLinkId
        self.attributedClickId = attributedClickId
        self.linkOpenedAt = linkOpenedAt
        self.sessionId = sessionId
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case installId
        case eventName
        case eventData
        case timestamp
        case sdkName
        case sdkVersion
        case attributedLinkId
        case attributedClickId
        case linkOpenedAt
        case sessionId
    }
}

// MARK: - AnyCodable Helper

/// A type-erased Codable value for handling arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type: \(type(of: value))"
                )
            )
        }
    }
}
