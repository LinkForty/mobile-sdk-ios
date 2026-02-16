//
//  CreateLinkTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import XCTest
@testable import LinkFortySDK

final class CreateLinkTests: XCTestCase {

    // MARK: - CreateLinkOptions Encoding Tests

    func testCreateLinkOptionsEncodingMinimal() throws {
        // Arrange
        let options = CreateLinkOptions()

        // Act
        let data = try JSONEncoder().encode(options)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Assert
        XCTAssertNotNil(json)
        // All fields should be absent or null for minimal options
        XCTAssertNil(json?["templateId"])
        XCTAssertNil(json?["title"])
        XCTAssertNil(json?["customCode"])
    }

    func testCreateLinkOptionsEncodingFull() throws {
        // Arrange
        let options = CreateLinkOptions(
            templateId: "tmpl-uuid",
            templateSlug: "promo",
            deepLinkParameters: ["route": "VIDEO_VIEWER", "id": "vid123"],
            title: "Summer Promo",
            description: "Check out our summer deals",
            customCode: "summer24",
            utmParameters: UTMParameters(source: "email", campaign: "summer")
        )

        // Act
        let data = try JSONEncoder().encode(options)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Assert
        XCTAssertEqual(json?["templateId"] as? String, "tmpl-uuid")
        XCTAssertEqual(json?["templateSlug"] as? String, "promo")
        XCTAssertEqual(json?["title"] as? String, "Summer Promo")
        XCTAssertEqual(json?["customCode"] as? String, "summer24")

        let dlParams = json?["deepLinkParameters"] as? [String: String]
        XCTAssertEqual(dlParams?["route"], "VIDEO_VIEWER")
        XCTAssertEqual(dlParams?["id"], "vid123")
    }

    // MARK: - CreateLinkResult Decoding Tests

    func testCreateLinkResultDecodingValid() throws {
        // Arrange
        let json = """
        {
            "url": "https://go.example.com/promo/abc123",
            "shortCode": "abc123",
            "linkId": "link-uuid-1"
        }
        """.data(using: .utf8)!

        // Act
        let result = try JSONDecoder().decode(CreateLinkResult.self, from: json)

        // Assert
        XCTAssertEqual(result.url, "https://go.example.com/promo/abc123")
        XCTAssertEqual(result.shortCode, "abc123")
        XCTAssertEqual(result.linkId, "link-uuid-1")
    }

    func testCreateLinkResultDecodingMissingFieldThrows() {
        // Arrange — missing linkId
        let json = """
        {
            "url": "https://go.example.com/abc123",
            "shortCode": "abc123"
        }
        """.data(using: .utf8)!

        // Act & Assert
        XCTAssertThrowsError(try JSONDecoder().decode(CreateLinkResult.self, from: json))
    }

    // MARK: - DashboardCreateLinkResponse Decoding Tests

    func testDashboardCreateLinkResponseDecodingSnakeCase() throws {
        // Arrange
        let json = """
        {
            "id": "link-uuid-2",
            "short_code": "xyz789"
        }
        """.data(using: .utf8)!

        // Act
        let response = try JSONDecoder().decode(DashboardCreateLinkResponse.self, from: json)

        // Assert
        XCTAssertEqual(response.id, "link-uuid-2")
        XCTAssertEqual(response.shortCode, "xyz789")
    }

    func testDashboardCreateLinkResponseCamelCaseFailsDecoding() {
        // Arrange — camelCase keys should NOT work (expects snake_case)
        let json = """
        {
            "id": "link-uuid-3",
            "shortCode": "abc456"
        }
        """.data(using: .utf8)!

        // Act
        let response = try? JSONDecoder().decode(DashboardCreateLinkResponse.self, from: json)

        // Assert — should fail because CodingKeys expects "short_code"
        XCTAssertNil(response?.shortCode)
    }
}
