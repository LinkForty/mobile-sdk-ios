//
//  StorageManager.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// Protocol for UserDefaults to enable mocking in tests
protocol UserDefaultsProtocol {
    func set(_ value: Any?, forKey key: String)
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func bool(forKey key: String) -> Bool
    func removeObject(forKey key: String)
}

extension UserDefaults: UserDefaultsProtocol {}

/// Manages persistent storage for the SDK using UserDefaults
final class StorageManager {
    // MARK: - Properties

    private let userDefaults: UserDefaultsProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Serial queue for thread-safe storage operations
    private let queue = DispatchQueue(label: "com.linkforty.sdk.storage", qos: .utility)

    // MARK: - Initialization

    /// Creates a storage manager with the specified UserDefaults
    /// - Parameter userDefaults: The UserDefaults instance to use (defaults to .standard)
    init(userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Install ID

    /// Saves the install ID
    /// - Parameter installId: The install ID to save
    func saveInstallId(_ installId: String) {
        queue.async { [weak self] in
            self?.userDefaults.set(installId, forKey: StorageKeys.installId)
        }
    }

    /// Retrieves the saved install ID
    /// - Returns: The install ID if it exists, nil otherwise
    func getInstallId() -> String? {
        queue.sync {
            userDefaults.string(forKey: StorageKeys.installId)
        }
    }

    // MARK: - Install Data

    /// Saves the deep link data from attribution
    /// - Parameter data: The deep link data to save
    func saveInstallData(_ data: DeepLinkData) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let encoded = try self.encoder.encode(data)
                self.userDefaults.set(encoded, forKey: StorageKeys.installData)
            } catch {
                if LinkFortyLogger.isDebugEnabled {
                    print("[LinkForty] Failed to encode install data: \(error)")
                }
            }
        }
    }

    /// Retrieves the saved deep link data
    /// - Returns: The deep link data if it exists and can be decoded, nil otherwise
    func getInstallData() -> DeepLinkData? {
        queue.sync {
            guard let data = userDefaults.data(forKey: StorageKeys.installData) else {
                return nil
            }

            do {
                return try decoder.decode(DeepLinkData.self, from: data)
            } catch {
                if LinkFortyLogger.isDebugEnabled {
                    print("[LinkForty] Failed to decode install data: \(error)")
                }
                return nil
            }
        }
    }

    // MARK: - First Launch

    /// Checks if this is the first launch of the app
    /// - Returns: True if this is the first launch, false otherwise
    func isFirstLaunch() -> Bool {
        queue.sync {
            // If the key doesn't exist, it defaults to false, so we invert the logic
            // We store "hasLaunched" and check if it's false
            let hasLaunched = userDefaults.bool(forKey: StorageKeys.firstLaunch)
            return !hasLaunched
        }
    }

    /// Marks that the app has launched (no longer first launch)
    func setHasLaunched() {
        queue.async { [weak self] in
            self?.userDefaults.set(true, forKey: StorageKeys.firstLaunch)
        }
    }

    // MARK: - Clear Data

    /// Clears all stored SDK data
    /// - Note: This removes install ID, install data, and first launch flag
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.userDefaults.removeObject(forKey: StorageKeys.installId)
            self.userDefaults.removeObject(forKey: StorageKeys.installData)
            self.userDefaults.removeObject(forKey: StorageKeys.firstLaunch)
        }
    }
}

// MARK: - Logger Helper

/// Simple logger for debug mode
struct LinkFortyLogger {
    static var isDebugEnabled = false

    static func log(_ message: String) {
        if isDebugEnabled {
            print("[LinkForty] \(message)")
        }
    }
}
