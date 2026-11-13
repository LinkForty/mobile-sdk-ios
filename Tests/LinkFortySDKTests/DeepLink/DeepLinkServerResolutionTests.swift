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
            baseURL: URL(string: "https://go.example.com")!,
            attributionContext: AttributionContext(
                defaults: UserDefaults(suiteName: "test-dl-\(UUID().uuidString)")!
            )
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
            baseURL: URL(string: "https://go.example.com")!,
            attributionContext: AttributionContext(
                defaults: UserDefaults(suiteName: "test-dl-\(UUID().uuidString)")!
            )
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

    // MARK: - Resolve request query

    /// Handles `url` with a mock network and returns the resolve endpoint requested.
    private func resolveEndpoint(for urlString: String) -> String? {
        let expectation = expectation(description: "Resolve \(urlString)")
        let mockNetworkManager = MockNetworkManager()
        mockNetworkManager.mockResponse = DeepLinkData(shortCode: "abc123", linkId: "link-uuid-1")

        sut.configure(
            networkManager: mockNetworkManager,
            fingerprintCollector: MockFingerprintCollector(),
            baseURL: URL(string: "https://go.example.com")!,
            attributionContext: AttributionContext(
                defaults: UserDefaults(suiteName: "test-dl-\(UUID().uuidString)")!
            )
        )
        sut.onDeepLink { _, _ in expectation.fulfill() }
        sut.handleDeepLink(URL(string: urlString)!)

        wait(for: [expectation], timeout: 2.0)
        return mockNetworkManager.lastEndpoint
    }

    /// The decoded query of a requested endpoint, as a server would read it ("+" is a space).
    private func query(of endpoint: String?) -> [String: String] {
        guard let endpoint = endpoint, let start = endpoint.firstIndex(of: "?") else { return [:] }
        var result: [String: String] = [:]
        for pair in endpoint[endpoint.index(after: start)...].split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map {
                String($0).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String($0)
            }
            result[parts[0]] = parts.count > 1 ? parts[1] : ""
        }
        return result
    }

    func testResolvePassesTheLinksQueryParametersWithTheFingerprint() {
        let endpoint = resolveEndpoint(for: "https://go.example.com/abc123?os_id=u1&utm_campaign=winback")

        XCTAssertTrue(endpoint?.hasPrefix("/api/sdk/v1/resolve/abc123?") ?? false)
        XCTAssertEqual(query(of: endpoint), [
            "os_id": "u1",
            "utm_campaign": "winback",
            "fp_tz": "America/New_York",
            "fp_lang": "en-US",
            "fp_sw": "1170",
            "fp_sh": "2532",
            "fp_platform": "iOS",
            "fp_pv": "15.0"
        ])
    }

    func testResolveKeepsItsOwnFingerprintOverFpParametersOnTheLink() {
        let query = query(of: resolveEndpoint(for: "https://go.example.com/abc123?fp_tz=evil&FP_LANG=evil&os_id=u1"))

        XCTAssertEqual(query["fp_tz"], "America/New_York")
        XCTAssertEqual(query["fp_lang"], "en-US")
        XCTAssertNil(query["FP_LANG"])
        XCTAssertEqual(query["os_id"], "u1")
    }

    func testResolveEncodesValuesOnce() {
        let query = query(of: resolveEndpoint(for: "https://go.example.com/abc123?note=a%20b%26c&email=a%2Bb%40example.com"))

        XCTAssertEqual(query["note"], "a b&c")
        XCTAssertEqual(query["email"], "a+b@example.com")
    }

    func testResolveReadsALiteralPlusInTheLinkAsASpace() {
        let query = query(of: resolveEndpoint(for: "https://go.example.com/abc123?iterable_id=a+b%40x.com&email=c%2Bd%40x.com"))

        XCTAssertEqual(query["iterable_id"], "a b@x.com")
        XCTAssertEqual(query["email"], "c+d@x.com")
    }

    func testResolveSendsOnlyTheFingerprintForALinkWithNoQuery() {
        let query = query(of: resolveEndpoint(for: "https://go.example.com/abc123"))

        XCTAssertEqual(query.keys.sorted(), ["fp_lang", "fp_platform", "fp_pv", "fp_sh", "fp_sw", "fp_tz"])
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
            baseURL: URL(string: "https://go.example.com")!,
            attributionContext: AttributionContext(
                defaults: UserDefaults(suiteName: "test-dl-\(UUID().uuidString)")!
            )
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
            baseURL: URL(string: "https://go.example.com")!,
            attributionContext: AttributionContext(
                defaults: UserDefaults(suiteName: "test-dl-\(UUID().uuidString)")!
            )
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
            baseURL: URL(string: "https://go.example.com")!,
            attributionContext: AttributionContext(
                defaults: UserDefaults(suiteName: "test-dl-\(UUID().uuidString)")!
            )
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
