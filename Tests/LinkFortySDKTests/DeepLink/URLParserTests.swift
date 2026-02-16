//
//  URLParserTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

final class URLParserTests: XCTestCase {

    // MARK: - Short Code Extraction Tests

    func testExtractShortCodeFromSimpleURL() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "abc123")
    }

    func testExtractShortCodeFromURLWithTrailingSlash() {
        // Arrange
        let url = URL(string: "https://go.example.com/xyz789/")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "xyz789")
    }

    func testExtractShortCodeFromURLWithQueryParameters() {
        // Arrange
        let url = URL(string: "https://go.example.com/test123?utm_source=email")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "test123")
    }

    func testExtractShortCodeFromRootURL() {
        // Arrange
        let url = URL(string: "https://go.example.com/")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertNil(shortCode)
    }

    func testExtractShortCodeFromCustomScheme() {
        // Arrange
        let url = URL(string: "myapp://deep/link123")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "link123")
    }

    // MARK: - UTM Parameter Extraction Tests

    func testExtractUTMParametersAllPresent() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?utm_source=facebook&utm_medium=cpc&utm_campaign=summer&utm_term=shoes&utm_content=banner")!

        // Act
        let utm = URLParser.extractUTMParameters(from: url)

        // Assert
        XCTAssertNotNil(utm)
        XCTAssertEqual(utm?.source, "facebook")
        XCTAssertEqual(utm?.medium, "cpc")
        XCTAssertEqual(utm?.campaign, "summer")
        XCTAssertEqual(utm?.term, "shoes")
        XCTAssertEqual(utm?.content, "banner")
    }

    func testExtractUTMParametersPartial() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?utm_source=email&utm_campaign=newsletter")!

        // Act
        let utm = URLParser.extractUTMParameters(from: url)

        // Assert
        XCTAssertNotNil(utm)
        XCTAssertEqual(utm?.source, "email")
        XCTAssertNil(utm?.medium)
        XCTAssertEqual(utm?.campaign, "newsletter")
        XCTAssertNil(utm?.term)
        XCTAssertNil(utm?.content)
    }

    func testExtractUTMParametersNone() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123")!

        // Act
        let utm = URLParser.extractUTMParameters(from: url)

        // Assert
        XCTAssertNil(utm)
    }

    func testExtractUTMParametersWithSpecialCharacters() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?utm_source=google%20ads&utm_campaign=test%2Bcampaign")!

        // Act
        let utm = URLParser.extractUTMParameters(from: url)

        // Assert
        XCTAssertNotNil(utm)
        XCTAssertEqual(utm?.source, "google ads")
        XCTAssertEqual(utm?.campaign, "test+campaign")
    }

    // MARK: - Custom Parameter Extraction Tests

    func testExtractCustomParametersSimple() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?productId=456&color=blue")!

        // Act
        let params = URLParser.extractCustomParameters(from: url)

        // Assert
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params["productId"], "456")
        XCTAssertEqual(params["color"], "blue")
    }

    func testExtractCustomParametersExcludesUTM() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?utm_source=email&productId=789&utm_campaign=test&size=large")!

        // Act
        let params = URLParser.extractCustomParameters(from: url)

        // Assert
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params["productId"], "789")
        XCTAssertEqual(params["size"], "large")
        XCTAssertNil(params["utm_source"])
        XCTAssertNil(params["utm_campaign"])
    }

    func testExtractCustomParametersEmpty() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123")!

        // Act
        let params = URLParser.extractCustomParameters(from: url)

        // Assert
        XCTAssertTrue(params.isEmpty)
    }

    func testExtractCustomParametersOnlyUTM() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?utm_source=facebook&utm_campaign=test")!

        // Act
        let params = URLParser.extractCustomParameters(from: url)

        // Assert
        XCTAssertTrue(params.isEmpty)
    }

    func testExtractCustomParametersWithSpecialCharacters() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?name=John%20Doe&email=test%40example.com")!

        // Act
        let params = URLParser.extractCustomParameters(from: url)

        // Assert
        XCTAssertEqual(params["name"], "John Doe")
        XCTAssertEqual(params["email"], "test@example.com")
    }

    // MARK: - Parse Deep Link Tests

    func testParseDeepLinkSimple() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123")!

        // Act
        let data = URLParser.parseDeepLink(from: url)

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.shortCode, "abc123")
        XCTAssertEqual(data?.iosURL, url.absoluteString)
        XCTAssertNil(data?.utmParameters)
        XCTAssertNil(data?.customParameters)
    }

    func testParseDeepLinkWithUTM() {
        // Arrange
        let url = URL(string: "https://go.example.com/test123?utm_source=email&utm_campaign=promo")!

        // Act
        let data = URLParser.parseDeepLink(from: url)

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.shortCode, "test123")
        XCTAssertEqual(data?.utmParameters?.source, "email")
        XCTAssertEqual(data?.utmParameters?.campaign, "promo")
        XCTAssertNil(data?.customParameters)
    }

    func testParseDeepLinkWithCustomParams() {
        // Arrange
        let url = URL(string: "https://go.example.com/link456?productId=789&category=electronics")!

        // Act
        let data = URLParser.parseDeepLink(from: url)

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.shortCode, "link456")
        XCTAssertNil(data?.utmParameters)
        XCTAssertNotNil(data?.customParameters)
        XCTAssertEqual(data?.customParameters?["productId"], "789")
        XCTAssertEqual(data?.customParameters?["category"], "electronics")
    }

    func testParseDeepLinkWithBothUTMAndCustom() {
        // Arrange
        let url = URL(string: "https://go.example.com/full123?utm_source=google&utm_campaign=sale&productId=999&referrer=blog")!

        // Act
        let data = URLParser.parseDeepLink(from: url)

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.shortCode, "full123")
        XCTAssertEqual(data?.utmParameters?.source, "google")
        XCTAssertEqual(data?.utmParameters?.campaign, "sale")
        XCTAssertEqual(data?.customParameters?["productId"], "999")
        XCTAssertEqual(data?.customParameters?["referrer"], "blog")
    }

    func testParseDeepLinkInvalidURL() {
        // Arrange
        let url = URL(string: "https://go.example.com/")!

        // Act
        let data = URLParser.parseDeepLink(from: url)

        // Assert
        XCTAssertNil(data)
    }

    func testParseDeepLinkCustomScheme() {
        // Arrange
        let url = URL(string: "myapp://product/abc123?id=456")!

        // Act
        let data = URLParser.parseDeepLink(from: url)

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.shortCode, "abc123")
        XCTAssertEqual(data?.customParameters?["id"], "456")
    }

    // MARK: - Edge Cases

    func testURLWithFragment() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123#section")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "abc123")
    }

    func testURLWithPort() {
        // Arrange
        let url = URL(string: "https://go.example.com:8080/test123")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "test123")
    }

    func testURLWithMultiplePathComponents() {
        // Arrange
        let url = URL(string: "https://go.example.com/path/to/link123")!

        // Act
        let shortCode = URLParser.extractShortCode(from: url)

        // Assert
        XCTAssertEqual(shortCode, "link123")
    }

    func testEmptyParameterValues() {
        // Arrange
        let url = URL(string: "https://go.example.com/abc123?utm_source=&productId=")!

        // Act
        let utm = URLParser.extractUTMParameters(from: url)
        let custom = URLParser.extractCustomParameters(from: url)

        // Assert
        // Empty values should be treated as empty strings
        XCTAssertNotNil(utm)
        XCTAssertEqual(utm?.source, "")
        XCTAssertEqual(custom["productId"], "")
    }
}
