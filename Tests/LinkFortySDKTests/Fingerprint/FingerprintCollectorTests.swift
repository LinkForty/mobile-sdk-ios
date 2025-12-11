//
//  FingerprintCollectorTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import LinkFortySDK

final class FingerprintCollectorTests: XCTestCase {
    var sut: FingerprintCollector!
    var mockDevice: MockUIDevice!
    var mockScreen: MockUIScreen!
    var mockBundle: MockBundle!
    var mockLocale: Locale!
    var mockTimeZone: TimeZone!

    override func setUp() {
        super.setUp()
        mockDevice = MockUIDevice()
        mockScreen = MockUIScreen()
        mockBundle = MockBundle()
        mockLocale = Locale(identifier: "en-US")
        mockTimeZone = TimeZone(identifier: "America/New_York")!

        sut = FingerprintCollector(
            device: mockDevice,
            screen: mockScreen,
            bundle: mockBundle,
            locale: mockLocale,
            timeZone: mockTimeZone
        )
    }

    override func tearDown() {
        sut = nil
        mockDevice = nil
        mockScreen = nil
        mockBundle = nil
        mockLocale = nil
        mockTimeZone = nil
        super.tearDown()
    }

    // MARK: - Basic Fingerprint Tests

    func testCollectFingerprintReturnsAllRequiredFields() {
        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertFalse(fingerprint.userAgent.isEmpty)
        XCTAssertFalse(fingerprint.timezone.isEmpty)
        XCTAssertFalse(fingerprint.language.isEmpty)
        XCTAssertGreaterThan(fingerprint.screenWidth, 0)
        XCTAssertGreaterThan(fingerprint.screenHeight, 0)
        XCTAssertEqual(fingerprint.platform, "iOS")
        XCTAssertFalse(fingerprint.platformVersion.isEmpty)
        XCTAssertFalse(fingerprint.appVersion.isEmpty)
        XCTAssertEqual(fingerprint.attributionWindowHours, 168)
    }

    func testCollectFingerprintWithoutDeviceId() {
        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertNil(fingerprint.deviceId)
    }

    func testCollectFingerprintWithDeviceId() {
        // Arrange
        let testDeviceId = "test-device-id-123"

        // Act
        let fingerprint = sut.collectFingerprint(
            attributionWindowHours: 168,
            deviceId: testDeviceId
        )

        // Assert
        XCTAssertEqual(fingerprint.deviceId, testDeviceId)
    }

    // MARK: - User-Agent Tests

    func testUserAgentFormat() {
        // Arrange
        mockBundle.mockDisplayName = "TestApp"
        mockBundle.mockVersion = "1.2.3"
        mockDevice.mockSystemVersion = "15.0"

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.userAgent, "TestApp/1.2.3 iOS/15.0")
    }

    func testUserAgentWithBundleNameFallback() {
        // Arrange
        mockBundle.mockDisplayName = nil
        mockBundle.mockBundleName = "com.example.app"
        mockBundle.mockVersion = "2.0.0"
        mockDevice.mockSystemVersion = "16.0"

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.userAgent, "com.example.app/2.0.0 iOS/16.0")
    }

    func testUserAgentWithDefaultAppName() {
        // Arrange
        mockBundle.mockDisplayName = nil
        mockBundle.mockBundleName = nil
        mockBundle.mockVersion = "1.0.0"
        mockDevice.mockSystemVersion = "14.0"

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.userAgent, "App/1.0.0 iOS/14.0")
    }

    func testUserAgentWithDefaultVersion() {
        // Arrange
        mockBundle.mockDisplayName = "MyApp"
        mockBundle.mockVersion = nil
        mockDevice.mockSystemVersion = "15.0"

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.userAgent, "MyApp/1.0.0 iOS/15.0")
    }

    // MARK: - Timezone Tests

    func testTimezoneIdentifier() {
        // Arrange
        let newYorkTimeZone = TimeZone(identifier: "America/New_York")!
        let collector = FingerprintCollector(
            device: mockDevice,
            screen: mockScreen,
            bundle: mockBundle,
            locale: mockLocale,
            timeZone: newYorkTimeZone
        )

        // Act
        let fingerprint = collector.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.timezone, "America/New_York")
    }

    func testDifferentTimezones() {
        // Arrange
        let timezones = [
            "America/Los_Angeles",
            "Europe/London",
            "Asia/Tokyo",
            "Australia/Sydney"
        ]

        for tzIdentifier in timezones {
            let tz = TimeZone(identifier: tzIdentifier)!
            let collector = FingerprintCollector(
                device: mockDevice,
                screen: mockScreen,
                bundle: mockBundle,
                locale: mockLocale,
                timeZone: tz
            )

            // Act
            let fingerprint = collector.collectFingerprint(attributionWindowHours: 168)

            // Assert
            XCTAssertEqual(fingerprint.timezone, tzIdentifier)
        }
    }

    // MARK: - Language Tests

    func testLanguageIdentifier() {
        // Arrange
        let locales = [
            ("en-US", Locale(identifier: "en-US")),
            ("es-MX", Locale(identifier: "es-MX")),
            ("fr-FR", Locale(identifier: "fr-FR")),
            ("ja-JP", Locale(identifier: "ja-JP"))
        ]

        for (expected, locale) in locales {
            let collector = FingerprintCollector(
                device: mockDevice,
                screen: mockScreen,
                bundle: mockBundle,
                locale: locale,
                timeZone: mockTimeZone
            )

            // Act
            let fingerprint = collector.collectFingerprint(attributionWindowHours: 168)

            // Assert
            XCTAssertEqual(fingerprint.language, expected)
        }
    }

    // MARK: - Screen Resolution Tests

    func testScreenResolution() {
        // Arrange - iPhone 15 Pro (393x852 points @ 3x scale = 1179x2556 pixels)
        mockScreen.mockBounds = CGRect(x: 0, y: 0, width: 393, height: 852)
        mockScreen.mockScale = 3.0

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.screenWidth, 1179)
        XCTAssertEqual(fingerprint.screenHeight, 2556)
    }

    func testScreenResolutionWithDifferentScales() {
        // Test @2x scale (e.g., iPhone SE)
        mockScreen.mockBounds = CGRect(x: 0, y: 0, width: 375, height: 667)
        mockScreen.mockScale = 2.0

        var fingerprint = sut.collectFingerprint(attributionWindowHours: 168)
        XCTAssertEqual(fingerprint.screenWidth, 750)
        XCTAssertEqual(fingerprint.screenHeight, 1334)

        // Test @3x scale (e.g., iPhone 15)
        mockScreen.mockBounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        mockScreen.mockScale = 3.0

        fingerprint = sut.collectFingerprint(attributionWindowHours: 168)
        XCTAssertEqual(fingerprint.screenWidth, 1170)
        XCTAssertEqual(fingerprint.screenHeight, 2532)
    }

    func testScreenResolutionIPad() {
        // iPad Pro 12.9" (1024x1366 points @ 2x scale)
        mockScreen.mockBounds = CGRect(x: 0, y: 0, width: 1024, height: 1366)
        mockScreen.mockScale = 2.0

        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        XCTAssertEqual(fingerprint.screenWidth, 2048)
        XCTAssertEqual(fingerprint.screenHeight, 2732)
    }

    // MARK: - Platform Tests

    func testPlatformAlwaysiOS() {
        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.platform, "iOS")
    }

    func testPlatformVersion() {
        // Arrange
        let versions = ["13.0", "14.5", "15.2", "16.0", "17.0"]

        for version in versions {
            mockDevice.mockSystemVersion = version

            // Act
            let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

            // Assert
            XCTAssertEqual(fingerprint.platformVersion, version)
        }
    }

    // MARK: - App Version Tests

    func testAppVersion() {
        // Arrange
        mockBundle.mockVersion = "2.5.1"

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.appVersion, "2.5.1")
    }

    func testAppVersionFallback() {
        // Arrange
        mockBundle.mockVersion = nil

        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(fingerprint.appVersion, "1.0.0")
    }

    // MARK: - Attribution Window Tests

    func testAttributionWindowHours() {
        // Test different attribution windows
        let windows = [24, 48, 168, 720, 2160]

        for window in windows {
            // Act
            let fingerprint = sut.collectFingerprint(attributionWindowHours: window)

            // Assert
            XCTAssertEqual(fingerprint.attributionWindowHours, window)
        }
    }

    // MARK: - Privacy Tests

    func testNoIDFACollectedByDefault() {
        // Act
        let fingerprint = sut.collectFingerprint(attributionWindowHours: 168)

        // Assert
        XCTAssertNil(fingerprint.deviceId, "IDFA should not be collected without explicit consent")
    }

    func testDeviceIdOnlySetWhenProvided() {
        // Act - without device ID
        let fingerprintWithout = sut.collectFingerprint(attributionWindowHours: 168)

        // Act - with device ID
        let fingerprintWith = sut.collectFingerprint(
            attributionWindowHours: 168,
            deviceId: "optional-idfa"
        )

        // Assert
        XCTAssertNil(fingerprintWithout.deviceId)
        XCTAssertEqual(fingerprintWith.deviceId, "optional-idfa")
    }

    // MARK: - Codable Tests

    func testFingerprintEncodingAndDecoding() throws {
        // Arrange
        let fingerprint = sut.collectFingerprint(
            attributionWindowHours: 168,
            deviceId: "test-id"
        )

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(fingerprint)

        // Act - Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceFingerprint.self, from: data)

        // Assert
        XCTAssertEqual(decoded.userAgent, fingerprint.userAgent)
        XCTAssertEqual(decoded.timezone, fingerprint.timezone)
        XCTAssertEqual(decoded.language, fingerprint.language)
        XCTAssertEqual(decoded.screenWidth, fingerprint.screenWidth)
        XCTAssertEqual(decoded.screenHeight, fingerprint.screenHeight)
        XCTAssertEqual(decoded.platform, fingerprint.platform)
        XCTAssertEqual(decoded.platformVersion, fingerprint.platformVersion)
        XCTAssertEqual(decoded.appVersion, fingerprint.appVersion)
        XCTAssertEqual(decoded.deviceId, fingerprint.deviceId)
        XCTAssertEqual(decoded.attributionWindowHours, fingerprint.attributionWindowHours)
    }
}

// MARK: - Mock Objects

class MockUIDevice: UIDeviceProtocol {
    var mockSystemVersion: String = "15.0"
    var mockModel: String = "iPhone"

    var systemVersion: String { mockSystemVersion }
    var model: String { mockModel }
}

class MockUIScreen: UIScreenProtocol {
    var mockBounds: CGRect = CGRect(x: 0, y: 0, width: 390, height: 844)
    var mockScale: CGFloat = 3.0

    var bounds: CGRect { mockBounds }
    var scale: CGFloat { mockScale }
}

class MockBundle: BundleProtocol {
    var mockDisplayName: String? = "TestApp"
    var mockBundleName: String? = "com.test.app"
    var mockVersion: String? = "1.0.0"

    func object(forInfoDictionaryKey key: String) -> Any? {
        switch key {
        case "CFBundleDisplayName":
            return mockDisplayName
        case "CFBundleName":
            return mockBundleName
        case "CFBundleShortVersionString":
            return mockVersion
        default:
            return nil
        }
    }
}
