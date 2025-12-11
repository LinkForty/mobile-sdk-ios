//
//  AttributionManager.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

// MARK: - Protocols for Dependency Injection

protocol NetworkManagerProtocol {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        headers: [String: String]?
    ) async throws -> T
}

protocol StorageManagerProtocol {
    func saveInstallId(_ installId: String)
    func saveInstallData(_ data: DeepLinkData)
    func setHasLaunched()
    func getInstallId() -> String?
    func getInstallData() -> DeepLinkData?
    func isFirstLaunch() -> Bool
    func clearAll()
}

protocol FingerprintCollectorProtocol {
    func collectFingerprint(
        attributionWindowHours: Int,
        deviceId: String?
    ) -> DeviceFingerprint
}

// MARK: - Protocol Conformance

@available(iOS 13.0, macOS 10.15, *)
extension NetworkManager: NetworkManagerProtocol {}

extension StorageManager: StorageManagerProtocol {}

extension FingerprintCollector: FingerprintCollectorProtocol {}

/// Manages install attribution and deferred deep linking
@available(iOS 13.0, macOS 10.15, *)
final class AttributionManager {
    // MARK: - Properties

    private let networkManager: NetworkManagerProtocol
    private let storageManager: StorageManagerProtocol
    private let fingerprintCollector: FingerprintCollectorProtocol

    // MARK: - Initialization

    /// Creates an attribution manager
    /// - Parameters:
    ///   - networkManager: Network manager for API requests
    ///   - storageManager: Storage manager for caching data
    ///   - fingerprintCollector: Fingerprint collector for device data
    init(
        networkManager: NetworkManagerProtocol,
        storageManager: StorageManagerProtocol,
        fingerprintCollector: FingerprintCollectorProtocol
    ) {
        self.networkManager = networkManager
        self.storageManager = storageManager
        self.fingerprintCollector = fingerprintCollector
    }

    // MARK: - Install Attribution

    /// Reports an install to the backend and retrieves attribution data
    ///
    /// - Parameters:
    ///   - attributionWindowHours: Attribution window in hours
    ///   - deviceId: Optional device ID (IDFA/IDFV) if user consented
    /// - Returns: Install response with attribution data
    /// - Throws: LinkFortyError on failure
    func reportInstall(
        attributionWindowHours: Int,
        deviceId: String? = nil
    ) async throws -> InstallResponse {
        // Collect device fingerprint
        let fingerprint = fingerprintCollector.collectFingerprint(
            attributionWindowHours: attributionWindowHours,
            deviceId: deviceId
        )

        LinkFortyLogger.log("Reporting install with fingerprint: \(fingerprint)")

        // Send install request to backend
        let response: InstallResponse = try await networkManager.request(
            endpoint: "/api/sdk/v1/install",
            method: .post,
            body: fingerprint,
            headers: nil
        )

        LinkFortyLogger.log("Install response: \(response)")

        // Cache install ID
        storageManager.saveInstallId(response.installId)

        // Cache deep link data if attributed
        if let deepLinkData = response.deepLinkData {
            storageManager.saveInstallData(deepLinkData)
            LinkFortyLogger.log("Install attributed with confidence: \(response.confidenceScore)%")
        } else {
            LinkFortyLogger.log("Organic install (no attribution)")
        }

        // Mark that app has launched
        storageManager.setHasLaunched()

        return response
    }

    // MARK: - Data Retrieval

    /// Retrieves the install ID
    /// - Returns: Install ID if available, nil otherwise
    func getInstallId() -> String? {
        storageManager.getInstallId()
    }

    /// Retrieves the cached install attribution data
    /// - Returns: Deep link data if available, nil otherwise
    func getInstallData() -> DeepLinkData? {
        storageManager.getInstallData()
    }

    /// Checks if this is the first launch
    /// - Returns: True if first launch, false otherwise
    func isFirstLaunch() -> Bool {
        storageManager.isFirstLaunch()
    }

    // MARK: - Data Management

    /// Clears all cached attribution data
    func clearData() {
        storageManager.clearAll()
        LinkFortyLogger.log("Attribution data cleared")
    }
}
