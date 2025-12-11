//
//  StorageKeys.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// UserDefaults keys used by the SDK
enum StorageKeys {
    /// Prefix for all LinkForty SDK keys
    private static let prefix = "com.linkforty.sdk"

    /// Install ID key
    static let installId = "\(prefix).installId"

    /// Install data key (DeepLinkData JSON)
    static let installData = "\(prefix).installData"

    /// First launch flag key
    static let firstLaunch = "\(prefix).firstLaunch"
}
