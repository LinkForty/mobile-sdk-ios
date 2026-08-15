//
//  InstallResponseTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

final class InstallResponseTests: XCTestCase {
    private func decode(_ json: String) throws -> InstallResponse {
        try JSONDecoder().decode(InstallResponse.self, from: Data(json.utf8))
    }

    // MARK: - Organic Installs

    /// The backend returns `deepLinkData: {}` (not `null`) for organic installs.
    func testDecodesEmptyDeepLinkDataObjectAsNil() throws {
        let json = """
        {
            "installId": "install-123",
            "attributed": false,
            "confidenceScore": 0,
            "matchedFactors": [],
            "deepLinkData": {}
        }
        """

        let response = try decode(json)

        XCTAssertEqual(response.installId, "install-123")
        XCTAssertFalse(response.attributed)
        XCTAssertEqual(response.confidenceScore, 0)
        XCTAssertTrue(response.matchedFactors.isEmpty)
        XCTAssertNil(response.deepLinkData)
    }

    func testDecodesNullDeepLinkDataAsNil() throws {
        let json = """
        {
            "installId": "install-123",
            "attributed": false,
            "confidenceScore": 0,
            "matchedFactors": [],
            "deepLinkData": null
        }
        """

        XCTAssertNil(try decode(json).deepLinkData)
    }

    func testDecodesMissingDeepLinkDataAsNil() throws {
        let json = """
        {
            "installId": "install-123",
            "attributed": false,
            "confidenceScore": 0,
            "matchedFactors": []
        }
        """

        XCTAssertNil(try decode(json).deepLinkData)
    }

    /// A deep link with no short code can't be routed to, so it is not worth
    /// failing the whole response over.
    func testDecodesDeepLinkDataWithoutShortCodeAsNil() throws {
        let json = """
        {
            "installId": "install-123",
            "attributed": false,
            "confidenceScore": 0,
            "matchedFactors": [],
            "deepLinkData": { "iosUrl": "myapp://product/456" }
        }
        """

        XCTAssertNil(try decode(json).deepLinkData)
    }

    // MARK: - Attributed Installs

    func testDecodesAttributedResponse() throws {
        let json = """
        {
            "installId": "install-123",
            "attributed": true,
            "confidenceScore": 85,
            "matchedFactors": ["userAgent", "timezone"],
            "deepLinkData": {
                "shortCode": "abc123",
                "iosUrl": "myapp://product/456",
                "deepLinkPath": "/product/456",
                "clickedAt": "2026-01-15T10:30:00Z"
            }
        }
        """

        let response = try decode(json)

        XCTAssertTrue(response.attributed)
        XCTAssertEqual(response.confidenceScore, 85)
        XCTAssertEqual(response.matchedFactors, ["userAgent", "timezone"])
        XCTAssertEqual(response.deepLinkData?.shortCode, "abc123")
        XCTAssertEqual(response.deepLinkData?.iosURL, "myapp://product/456")
        XCTAssertEqual(response.deepLinkData?.deepLinkPath, "/product/456")
        XCTAssertNotNil(response.deepLinkData?.clickedAt)
    }

    // MARK: - Required Fields

    func testThrowsWhenInstallIdMissing() {
        let json = """
        {
            "attributed": false,
            "confidenceScore": 0,
            "matchedFactors": []
        }
        """

        XCTAssertThrowsError(try decode(json))
    }

    // MARK: - Round Trip

    func testRoundTripsThroughEncoding() throws {
        let original = InstallResponse(
            installId: "install-123",
            attributed: true,
            confidenceScore: 85,
            matchedFactors: ["userAgent"],
            deepLinkData: DeepLinkData(shortCode: "abc123", iosURL: "myapp://product/456")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InstallResponse.self, from: data)

        XCTAssertEqual(decoded.installId, original.installId)
        XCTAssertEqual(decoded.attributed, original.attributed)
        XCTAssertEqual(decoded.confidenceScore, original.confidenceScore)
        XCTAssertEqual(decoded.matchedFactors, original.matchedFactors)
        XCTAssertEqual(decoded.deepLinkData, original.deepLinkData)
    }
}
