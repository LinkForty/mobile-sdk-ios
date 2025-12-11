//
//  FingerprintCollector.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Protocol for UIDevice to enable mocking in tests
protocol UIDeviceProtocol {
    var systemVersion: String { get }
    var model: String { get }
}

#if canImport(UIKit)
extension UIDevice: UIDeviceProtocol {}
#endif

/// Protocol for UIScreen to enable mocking in tests
protocol UIScreenProtocol {
    var bounds: CGRect { get }
    var scale: CGFloat { get }
}

#if canImport(UIKit)
extension UIScreen: UIScreenProtocol {}
#endif

/// Protocol for Bundle to enable mocking in tests
protocol BundleProtocol {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: BundleProtocol {}

/// Collects device fingerprint data for attribution matching
final class FingerprintCollector {
    // MARK: - Properties

    private let device: UIDeviceProtocol
    private let screen: UIScreenProtocol
    private let bundle: BundleProtocol
    private let locale: Locale
    private let timeZone: TimeZone

    // MARK: - Initialization

    /// Creates a fingerprint collector
    /// - Parameters:
    ///   - device: UIDevice instance (defaults to .current)
    ///   - screen: UIScreen instance (defaults to .main)
    ///   - bundle: Bundle instance (defaults to .main)
    ///   - locale: Locale instance (defaults to .current)
    ///   - timeZone: TimeZone instance (defaults to .current)
    init(
        device: UIDeviceProtocol,
        screen: UIScreenProtocol,
        bundle: BundleProtocol,
        locale: Locale,
        timeZone: TimeZone
    ) {
        self.device = device
        self.screen = screen
        self.bundle = bundle
        self.locale = locale
        self.timeZone = timeZone
    }

    /// Convenience initializer for production use
    convenience init() {
        #if canImport(UIKit)
        self.init(
            device: UIDevice.current,
            screen: UIScreen.main,
            bundle: Bundle.main,
            locale: .current,
            timeZone: .current
        )
        #else
        // For macOS or other platforms, use default values
        self.init(
            device: MacOSDevice(),
            screen: MacOSScreen(),
            bundle: Bundle.main,
            locale: .current,
            timeZone: .current
        )
        #endif
    }

    // MARK: - Fingerprint Collection

    /// Collects device fingerprint for attribution
    /// - Parameters:
    ///   - attributionWindowHours: Attribution window in hours
    ///   - deviceId: Optional device ID (IDFA/IDFV) if user consented
    /// - Returns: Device fingerprint
    func collectFingerprint(
        attributionWindowHours: Int,
        deviceId: String? = nil
    ) -> DeviceFingerprint {
        DeviceFingerprint(
            userAgent: generateUserAgent(),
            timezone: timeZone.identifier,
            language: locale.identifier,
            screenWidth: Int(nativeScreenWidth),
            screenHeight: Int(nativeScreenHeight),
            platform: "iOS",
            platformVersion: device.systemVersion,
            appVersion: appVersion,
            deviceId: deviceId,
            attributionWindowHours: attributionWindowHours
        )
    }

    // MARK: - Private Helpers

    /// Generates a User-Agent string
    /// Format: "AppName/AppVersion iOS/SystemVersion"
    private func generateUserAgent() -> String {
        let appName = bundleDisplayName ?? bundleName ?? "App"
        let appVer = appVersion
        let systemVer = device.systemVersion

        return "\(appName)/\(appVer) iOS/\(systemVer)"
    }

    /// Native screen width (in pixels, accounting for scale)
    private var nativeScreenWidth: CGFloat {
        #if canImport(CoreGraphics)
        return screen.bounds.width * screen.scale
        #else
        return screen.bounds.size.width * screen.scale
        #endif
    }

    /// Native screen height (in pixels, accounting for scale)
    private var nativeScreenHeight: CGFloat {
        #if canImport(CoreGraphics)
        return screen.bounds.height * screen.scale
        #else
        return screen.bounds.size.height * screen.scale
        #endif
    }

    /// App version from bundle
    private var appVersion: String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0.0"
    }

    /// App bundle name
    private var bundleName: String? {
        bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    /// App display name (preferred over bundle name)
    private var bundleDisplayName: String? {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}

// MARK: - macOS Compatibility

#if !canImport(UIKit)
/// macOS device stub for testing
class MacOSDevice: UIDeviceProtocol {
    var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    var model: String {
        "Mac"
    }
}

/// macOS screen stub for testing
class MacOSScreen: UIScreenProtocol {
    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    var scale: CGFloat {
        2.0
    }
}
#endif
