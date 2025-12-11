//
//  URLSessionProtocol.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Protocol for URLSession to enable mocking in tests
@available(iOS 13.0, macOS 10.15, *)
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

@available(iOS 13.0, macOS 10.15, *)
extension URLSession: URLSessionProtocol {}
