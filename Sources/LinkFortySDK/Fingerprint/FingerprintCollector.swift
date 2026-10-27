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
    ///   - appToken: Optional public workspace token that scopes the install to a workspace
    /// - Returns: Device fingerprint
    func collectFingerprint(
        attributionWindowHours: Int,
        deviceId: String? = nil,
        appToken: String? = nil
    ) -> DeviceFingerprint {
        DeviceFingerprint(
            userAgent: generateUserAgent(),
            timezone: timeZone.identifier,
            language: Self.languageTag(for: locale),
            screenWidth: Int(nativeScreenWidth),
            screenHeight: Int(nativeScreenHeight),
            platform: "iOS",
            platformVersion: device.systemVersion,
            appVersion: appVersion,
            deviceId: deviceId,
            attributionWindowHours: attributionWindowHours,
            appToken: appToken,
            sdkName: SDKInfo.name,
            sdkVersion: SDKInfo.version
        )
    }

    // MARK: - Language

    /// The device language as `language` or `language-REGION` (`en-GB`, `zh-CN`, `es-419`).
    ///
    /// `Locale.identifier` can carry a script (`zh-Hans_CN`) and keywords for the
    /// user's region, calendar or number settings (`en_GB@rg=eszzzz`,
    /// `en_US@calendar=japanese`). Only the language and its region are sent, which
    /// is the same shape a browser on the device sends in `Accept-Language`. The
    /// region is the one in the language (`en_GB@rg=eszzzz` → `en-GB`), not the
    /// `rg` override. An identifier with no recognizable language is sent as is.
    static func languageTag(for locale: Locale) -> String {
        let identifier = locale.identifier
        let base = identifier.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let subtags = base.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)

        guard let language = subtags.first,
              (2...3).contains(language.count),
              language.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return identifier
        }

        for subtag in subtags.dropFirst() {
            // A single-character subtag starts an extension or private-use section.
            if subtag.count <= 1 { break }
            let isLetterRegion = subtag.count == 2 && subtag.allSatisfy { $0.isASCII && $0.isLetter }
            let isNumericRegion = subtag.count == 3 && subtag.allSatisfy { $0.isASCII && $0.isNumber }
            if isLetterRegion || isNumericRegion {
                return "\(language.lowercased())-\(subtag.uppercased())"
            }
        }
        return language.lowercased()
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
