//
//  LinkFortyError.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Errors that can occur when using the LinkForty SDK
public enum LinkFortyError: Error {
    /// The SDK has not been initialized
    /// - Note: Call `LinkForty.shared.initialize(config:)` before using other SDK methods
    case notInitialized

    /// The SDK has already been initialized
    /// - Note: `initialize(config:)` can only be called once
    case alreadyInitialized

    /// The configuration is invalid
    case invalidConfiguration(String)

    /// A network error occurred
    case networkError(Error)

    /// The server returned an invalid response
    case invalidResponse(statusCode: Int?, message: String?)

    /// Failed to decode the response
    case decodingError(Error)

    /// Failed to encode the request
    case encodingError(Error)

    /// Invalid event data
    case invalidEventData(String)

    /// Invalid deep link URL
    case invalidDeepLinkURL(String)
}

// MARK: - LocalizedError

extension LinkFortyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "LinkForty SDK is not initialized. Call initialize(config:) first."

        case .alreadyInitialized:
            return "LinkForty SDK has already been initialized."

        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .invalidResponse(let statusCode, let message):
            let code = statusCode.map { " (status: \($0))" } ?? ""
            let msg = message.map { ": \($0)" } ?? ""
            return "Invalid server response\(code)\(msg)"

        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"

        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"

        case .invalidEventData(let message):
            return "Invalid event data: \(message)"

        case .invalidDeepLinkURL(let message):
            return "Invalid deep link URL: \(message)"
        }
    }
}

// MARK: - CustomStringConvertible

extension LinkFortyError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown LinkFortyError"
    }
}
