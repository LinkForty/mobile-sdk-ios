//
//  DeepLinkDataTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import XCTest
@testable import LinkFortySDK

final class DeepLinkDataTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithRequiredFieldsOnly() {
        // Act
        let data = DeepLinkData(shortCode: "abc123")

        // Assert
        XCTAssertEqual(data.shortCode, "abc123")
        XCTAssertNil(data.iosURL)
        XCTAssertNil(data.androidURL)
        XCTAssertNil(data.webURL)
        XCTAssertNil(data.utmParameters)
        XCTAssertNil(data.customParameters)
        XCTAssertNil(data.deepLinkPath)
        XCTAssertNil(data.appScheme)
        XCTAssertNil(data.clickedAt)
        XCTAssertNil(data.linkId)
    }

    func testInitWithAllFields() {
        // Arrange
        let clickDate = Date()

        // Act
        let data = DeepLinkData(
            shortCode: "full123",
            iosURL: "myapp://product/456",
            androidURL: "android-app://product/456",
            webURL: "https://example.com/product/456",
            utmParameters: UTMParameters(source: "email", campaign: "launch"),
            customParameters: ["key": "value"],
            deepLinkPath: "/product/456",
            appScheme: "myapp",
            clickedAt: clickDate,
            linkId: "link-uuid-1"
        )

        // Assert
        XCTAssertEqual(data.shortCode, "full123")
        XCTAssertEqual(data.iosURL, "myapp://product/456")
        XCTAssertEqual(data.androidURL, "android-app://product/456")
        XCTAssertEqual(data.webURL, "https://example.com/product/456")
        XCTAssertEqual(data.utmParameters?.source, "email")
        XCTAssertEqual(data.utmParameters?.campaign, "launch")
        XCTAssertEqual(data.customParameters?["key"], "value")
        XCTAssertEqual(data.deepLinkPath, "/product/456")
        XCTAssertEqual(data.appScheme, "myapp")
        XCTAssertEqual(data.clickedAt, clickDate)
        XCTAssertEqual(data.linkId, "link-uuid-1")
    }

    // MARK: - JSON Decoding Tests

    func testDecodingWithNewFields() throws {
        // Arrange
        let json = """
        {
            "shortCode": "new123",
            "iosUrl": "myapp://test",
            "deepLinkPath": "/product/789",
            "appScheme": "myapp",
            "clickedAt": "2025-06-15T12:00:00Z",
            "linkId": "link-uuid-2"
        }
        """.data(using: .utf8)!

        // Act
        let data = try JSONDecoder().decode(DeepLinkData.self, from: json)

        // Assert
        XCTAssertEqual(data.shortCode, "new123")
        XCTAssertEqual(data.iosURL, "myapp://test")
        XCTAssertEqual(data.deepLinkPath, "/product/789")
        XCTAssertEqual(data.appScheme, "myapp")
        XCTAssertNotNil(data.clickedAt)
        XCTAssertEqual(data.linkId, "link-uuid-2")
    }

    func testDecodingWithoutNewFieldsBackwardCompat() throws {
        // Arrange — JSON from a v1.0.0 server that doesn't return new fields
        let json = """
        {
            "shortCode": "old123",
            "iosUrl": "myapp://legacy"
        }
        """.data(using: .utf8)!

        // Act
        let data = try JSONDecoder().decode(DeepLinkData.self, from: json)

        // Assert
        XCTAssertEqual(data.shortCode, "old123")
        XCTAssertEqual(data.iosURL, "myapp://legacy")
        XCTAssertNil(data.deepLinkPath)
        XCTAssertNil(data.appScheme)
        XCTAssertNil(data.clickedAt)
        XCTAssertNil(data.linkId)
    }

    func testDecodingClickedAtISO8601() throws {
        // Arrange
        let json = """
        {
            "shortCode": "date123",
            "clickedAt": "2025-01-15T08:30:00Z"
        }
        """.data(using: .utf8)!

        // Act
        let data = try JSONDecoder().decode(DeepLinkData.self, from: json)

        // Assert
        XCTAssertNotNil(data.clickedAt)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: data.clickedAt!)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - JSON Encoding Tests

    func testEncodingIncludesNewFields() throws {
        // Arrange
        let data = DeepLinkData(
            shortCode: "enc123",
            deepLinkPath: "/test/path",
            appScheme: "testapp",
            linkId: "link-uuid-3"
        )

        // Act
        let encoded = try JSONEncoder().encode(data)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Assert
        XCTAssertEqual(json?["shortCode"] as? String, "enc123")
        XCTAssertEqual(json?["deepLinkPath"] as? String, "/test/path")
        XCTAssertEqual(json?["appScheme"] as? String, "testapp")
        XCTAssertEqual(json?["linkId"] as? String, "link-uuid-3")
    }

    func testEncodingOmitsNils() throws {
        // Arrange
        let data = DeepLinkData(shortCode: "min123")

        // Act
        let encoded = try JSONEncoder().encode(data)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Assert
        XCTAssertEqual(json?["shortCode"] as? String, "min123")
        XCTAssertNil(json?["iosUrl"])
        XCTAssertNil(json?["deepLinkPath"])
        XCTAssertNil(json?["appScheme"])
        XCTAssertNil(json?["clickedAt"])
        XCTAssertNil(json?["linkId"])
    }

    func testEncodingClickedAtAsISO8601() throws {
        // Arrange
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2025-06-15T12:00:00Z")!
        let data = DeepLinkData(shortCode: "ts123", clickedAt: date)

        // Act
        let encoded = try JSONEncoder().encode(data)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Assert
        let clickedAtString = json?["clickedAt"] as? String
        XCTAssertNotNil(clickedAtString)
        XCTAssertEqual(clickedAtString, "2025-06-15T12:00:00Z")
    }

    // MARK: - CodingKeys Tests

    func testCodingKeysMappings() throws {
        // Arrange — use JSON keys that match CodingKeys (iosUrl, androidUrl, webUrl)
        let json = """
        {
            "shortCode": "keys123",
            "iosUrl": "ios://test",
            "androidUrl": "android://test",
            "webUrl": "https://test.com"
        }
        """.data(using: .utf8)!

        // Act
        let data = try JSONDecoder().decode(DeepLinkData.self, from: json)

        // Assert — Swift properties use different names
        XCTAssertEqual(data.iosURL, "ios://test")
        XCTAssertEqual(data.androidURL, "android://test")
        XCTAssertEqual(data.webURL, "https://test.com")
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        // Arrange
        let data1 = DeepLinkData(shortCode: "eq123", deepLinkPath: "/test")
        let data2 = DeepLinkData(shortCode: "eq123", deepLinkPath: "/test")

        // Assert
        XCTAssertEqual(data1, data2)
    }

    func testNotEqualWithDifferentDeepLinkPath() {
        // Arrange
        let data1 = DeepLinkData(shortCode: "eq123", deepLinkPath: "/path/a")
        let data2 = DeepLinkData(shortCode: "eq123", deepLinkPath: "/path/b")

        // Assert
        XCTAssertNotEqual(data1, data2)
    }

    // MARK: - Round-Trip Tests

    func testRoundTripEncodeDecode() throws {
        // Arrange
        let formatter = ISO8601DateFormatter()
        let clickDate = formatter.date(from: "2025-03-20T10:15:00Z")!

        let original = DeepLinkData(
            shortCode: "rt123",
            iosURL: "myapp://round/trip",
            androidURL: "android-app://round/trip",
            webURL: "https://example.com/round/trip",
            utmParameters: UTMParameters(source: "test", campaign: "roundtrip"),
            customParameters: ["foo": "bar", "baz": "qux"],
            deepLinkPath: "/round/trip",
            appScheme: "myapp",
            clickedAt: clickDate,
            linkId: "link-uuid-rt"
        )

        // Act
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeepLinkData.self, from: encoded)

        // Assert
        XCTAssertEqual(decoded.shortCode, original.shortCode)
        XCTAssertEqual(decoded.iosURL, original.iosURL)
        XCTAssertEqual(decoded.androidURL, original.androidURL)
        XCTAssertEqual(decoded.webURL, original.webURL)
        XCTAssertEqual(decoded.utmParameters?.source, original.utmParameters?.source)
        XCTAssertEqual(decoded.utmParameters?.campaign, original.utmParameters?.campaign)
        XCTAssertEqual(decoded.customParameters, original.customParameters)
        XCTAssertEqual(decoded.deepLinkPath, original.deepLinkPath)
        XCTAssertEqual(decoded.appScheme, original.appScheme)
        XCTAssertEqual(decoded.linkId, original.linkId)
        // Date comparison: ISO 8601 round-trip loses sub-second precision, compare strings
        let fmt = ISO8601DateFormatter()
        XCTAssertEqual(fmt.string(from: decoded.clickedAt!), fmt.string(from: original.clickedAt!))
    }
}
