//
//  NetworkManager.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Manages network requests for the SDK
@available(iOS 13.0, macOS 10.15, *)
final class NetworkManager {
    // MARK: - Properties

    private let config: LinkFortyConfig
    private let session: URLSessionProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Maximum number of retry attempts
    private let maxRetries = 3

    /// Timeout for network requests
    private let timeout: TimeInterval = 30

    // MARK: - Initialization

    /// Creates a network manager with the specified configuration
    /// - Parameters:
    ///   - config: SDK configuration
    ///   - session: URL session to use (defaults to .shared)
    init(config: LinkFortyConfig, session: URLSessionProtocol = URLSession.shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Public API

    /// Performs a network request and decodes the response
    ///
    /// - Parameters:
    ///   - endpoint: API endpoint path (e.g., "/api/sdk/v1/install")
    ///   - method: HTTP method
    ///   - body: Optional request body (must be Encodable)
    ///   - headers: Optional additional headers
    /// - Returns: Decoded response of type T
    /// - Throws: LinkFortyError on failure
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await performRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    headers: headers
                )
            } catch let error as LinkFortyError {
                lastError = error

                // Don't retry on client errors (4xx) or invalid configuration
                switch error {
                case .invalidResponse(let statusCode, _):
                    if let code = statusCode, (400..<500).contains(code) {
                        throw error
                    }
                case .invalidConfiguration, .decodingError, .encodingError:
                    throw error
                default:
                    break
                }

                // Exponential backoff: 1s, 2s, 4s
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1))
                    LinkFortyLogger.log("Request failed (attempt \(attempt)/\(maxRetries)), retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = error
                throw LinkFortyError.networkError(error)
            }
        }

        throw lastError ?? LinkFortyError.networkError(NSError(domain: "LinkForty", code: -1))
    }

    // MARK: - Private Methods

    /// Performs a single network request
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        headers: [String: String]?
    ) async throws -> T {
        // Build URL
        guard let url = URL(string: endpoint, relativeTo: config.baseURL) else {
            throw LinkFortyError.invalidConfiguration("Invalid endpoint: \(endpoint)")
        }

        // Build request
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.rawValue

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if present
        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body if present
        if let body = body {
            do {
                request.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw LinkFortyError.encodingError(error)
            }
        }

        // Log request in debug mode
        if config.debug {
            logRequest(request)
        }

        // Perform request
        let (data, response) = try await session.data(for: request)

        // Log response in debug mode
        if config.debug {
            logResponse(response, data: data)
        }

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinkFortyError.invalidResponse(statusCode: nil, message: "Not an HTTP response")
        }

        // Check status code
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw LinkFortyError.invalidResponse(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LinkFortyError.decodingError(error)
        }
    }

    // MARK: - Logging

    private func logRequest(_ request: URLRequest) {
        var log = "[LinkForty] → \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"

        if let apiKey = config.apiKey {
            log += "\n  Authorization: Bearer ***\(apiKey.suffix(4))"
        }

        if let body = request.httpBody,
           let jsonString = String(data: body, encoding: .utf8) {
            log += "\n  Body: \(jsonString)"
        }

        LinkFortyLogger.log(log)
    }

    private func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        var log = "[LinkForty] ← \(httpResponse.statusCode)"

        if let jsonString = String(data: data, encoding: .utf8) {
            log += "\n  Response: \(jsonString)"
        }

        LinkFortyLogger.log(log)
    }
}

// MARK: - AnyEncodable Helper

/// A type-erased Encodable value
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ encodable: Encodable) {
        _encode = encodable.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
