//
//  MockHelpers.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation
@testable import LinkFortySDK

// MARK: - Mock Network Manager

@available(iOS 13.0, macOS 10.15, *)
class MockNetworkManager: NetworkManagerProtocol {
    var mockResponse: Any?
    var mockError: Error?
    var lastEndpoint: String?
    var lastMethod: HTTPMethod?
    var lastBody: Any?

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        headers: [String: String]? = nil
    ) async throws -> T {
        lastEndpoint = endpoint
        lastMethod = method
        lastBody = body

        if let error = mockError {
            throw error
        }

        guard let mockResponse = mockResponse else {
            throw LinkFortyError.invalidResponse(statusCode: nil, message: "No mock response")
        }

        // Try direct cast first
        if let response = mockResponse as? T {
            return response
        }

        throw LinkFortyError.invalidResponse(statusCode: nil, message: "Mock response type mismatch")
    }
}

// MARK: - Mock Storage Manager

class MockStorageManager: StorageManagerProtocol {
    var savedInstallId: String?
    var savedInstallData: DeepLinkData?
    var hasLaunchedCalled = false
    var clearAllCalled = false

    var mockInstallId: String?
    var mockInstallData: DeepLinkData?
    var mockIsFirstLaunch = true

    func saveInstallId(_ installId: String) {
        savedInstallId = installId
    }

    func saveInstallData(_ data: DeepLinkData) {
        savedInstallData = data
    }

    func setHasLaunched() {
        hasLaunchedCalled = true
    }

    func getInstallId() -> String? {
        mockInstallId
    }

    func getInstallData() -> DeepLinkData? {
        mockInstallData
    }

    func isFirstLaunch() -> Bool {
        mockIsFirstLaunch
    }

    func clearAll() {
        clearAllCalled = true
    }
}
