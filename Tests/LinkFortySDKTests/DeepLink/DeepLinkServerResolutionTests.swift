//
//  DeepLinkServerResolutionTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

final class DeepLinkServerResolutionTests: XCTestCase {
    var sut: DeepLinkHandler!

    override func setUp() {
        super.setUp()
        sut = DeepLinkHandler()
    }

    override func tearDown() {
        sut.clearCallbacks()
        sut = nil
        super.tearDown()
    }

    // MARK: - Server-Side Resolution Tests

    func testHandleDeepLinkWithServerResolution() {
        // Arrange
        let expectation = expectation(description: "Server resolution")
        let mockNetworkManager = MockNetworkManager()
        let mockFingerprintCollector = MockFingerprintCollector()

        let enrichedData = DeepLinkData(
            shortCode: "abc123",
            iosURL: "myapp://product/456",
            deepLinkPath: "/product/456",
            appScheme: "myapp",
            linkId: "link-uuid-1"
        )
        mockNetworkManager.mockResponse = enrichedData

        sut.configure(
            networkManager: mockNetworkManager,
            fingerprintCollector: mockFingerprintCollector,
            baseURL: URL(string: "https://go.example.com")!
        )

        let url = URL(string: "https://go.example.com/abc123")!
        var receivedData: DeepLinkData?

        // Act
        sut.onDeepLink { _, data in
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedData)
        XCTAssertEqual(receivedData?.shortCode, "abc123")
        XCTAssertEqual(receivedData?.deepLinkPath, "/product/456")
        XCTAssertEqual(receivedData?.appScheme, "myapp")
        XCTAssertEqual(receivedData?.linkId, "link-uuid-1")
        XCTAssertTrue(mockNetworkManager.lastEndpoint?.contains("/api/sdk/v1/resolve/") ?? false)
    }

    func testHandleDeepLinkServerResolutionWithTemplateSlug() {
        // Arrange
        let expectation = expectation(description: "Template slug resolution")
        let mockNetworkManager = MockNetworkManager()
        let mockFingerprintCollector = MockFingerprintCollector()

        let enrichedData = DeepLinkData(shortCode: "abc123", deepLinkPath: "/product/789")
        mockNetworkManager.mockResponse = enrichedData

        sut.configure(
            networkManager: mockNetworkManager,
            fingerprintCollector: mockFingerprintCollector,
            baseURL: URL(string: "https://go.example.com")!
        )

        let url = URL(string: "https://go.example.com/tmpl/abc123")!

        // Act
        sut.onDeepLink { _, _ in
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(mockNetworkManager.lastEndpoint?.hasPrefix("/api/sdk/v1/resolve/tmpl/abc123") ?? false)
    }

    func testHandleDeepLinkServerResolutionFallsBackOnError() {
        // Arrange
        let expectation = expectation(description: "Fallback on error")
        let mockNetworkManager = MockNetworkManager()
        let mockFingerprintCollector = MockFingerprintCollector()

        mockNetworkManager.mockError = LinkFortyError.networkError(
            NSError(domain: "test", code: -1)
        )

        sut.configure(
            networkManager: mockNetworkManager,
            fingerprintCollector: mockFingerprintCollector,
            baseURL: URL(string: "https://go.example.com")!
        )

        let url = URL(string: "https://go.example.com/fallback123?utm_source=test")!
        var receivedData: DeepLinkData?

        // Act
        sut.onDeepLink { _, data in
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedData)
        XCTAssertEqual(receivedData?.shortCode, "fallback123")
        XCTAssertEqual(receivedData?.utmParameters?.source, "test")
    }

    func testHandleDeepLinkWithoutConfigurationUsesLocalParse() {
        // Arrange
        let expectation = expectation(description: "Local parse without configure")
        let url = URL(string: "https://go.example.com/local123?utm_campaign=summer")!

        var receivedData: DeepLinkData?

        // Act — no configure() call, handler has no network manager
        sut.onDeepLink { _, data in
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedData)
        XCTAssertEqual(receivedData?.shortCode, "local123")
        XCTAssertEqual(receivedData?.utmParameters?.campaign, "summer")
    }

    func testHandleDeepLinkServerResolutionSendsFingerprintParams() {
        // Arrange
        let expectation = expectation(description: "Fingerprint params sent")
        let mockNetworkManager = MockNetworkManager()
        let mockFingerprintCollector = MockFingerprintCollector()

        let enrichedData = DeepLinkData(shortCode: "fp123")
        mockNetworkManager.mockResponse = enrichedData

        sut.configure(
            networkManager: mockNetworkManager,
            fingerprintCollector: mockFingerprintCollector,
            baseURL: URL(string: "https://go.example.com")!
        )

        let url = URL(string: "https://go.example.com/fp123")!

        // Act
        sut.onDeepLink { _, _ in
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 2.0)

        let endpoint = mockNetworkManager.lastEndpoint ?? ""
        XCTAssertTrue(endpoint.contains("fp_tz="), "Endpoint should contain fp_tz")
        XCTAssertTrue(endpoint.contains("fp_lang="), "Endpoint should contain fp_lang")
        XCTAssertTrue(endpoint.contains("fp_sw="), "Endpoint should contain fp_sw")
        XCTAssertTrue(endpoint.contains("fp_sh="), "Endpoint should contain fp_sh")
        XCTAssertTrue(endpoint.contains("fp_platform="), "Endpoint should contain fp_platform")
        XCTAssertTrue(endpoint.contains("fp_pv="), "Endpoint should contain fp_pv")
    }

    func testHandleDeepLinkServerResolutionWithRootURL() {
        // Arrange
        let expectation = expectation(description: "Root URL")
        let mockNetworkManager = MockNetworkManager()
        let mockFingerprintCollector = MockFingerprintCollector()

        sut.configure(
            networkManager: mockNetworkManager,
            fingerprintCollector: mockFingerprintCollector,
            baseURL: URL(string: "https://go.example.com")!
        )

        let url = URL(string: "https://go.example.com/")!
        var receivedData: DeepLinkData?

        // Act
        sut.onDeepLink { _, data in
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNil(receivedData)
    }
}
