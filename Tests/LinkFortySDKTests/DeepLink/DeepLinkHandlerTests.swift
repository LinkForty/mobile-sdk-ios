//
//  DeepLinkHandlerTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import XCTest
@testable import LinkFortySDK

final class DeepLinkHandlerTests: XCTestCase {
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

    // MARK: - Deferred Deep Link Tests

    func testOnDeferredDeepLinkRegistersCallback() {
        // Arrange
        let expectation = expectation(description: "Callback registered")
        var callbackInvoked = false

        // Act
        sut.onDeferredDeepLink { _ in
            callbackInvoked = true
            expectation.fulfill()
        }

        sut.deliverDeferredDeepLink(nil)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(callbackInvoked)
    }

    func testDeferredDeepLinkWithAttributedData() {
        // Arrange
        let expectation = expectation(description: "Deferred deep link delivered")
        let testData = DeepLinkData(
            shortCode: "abc123",
            iosURL: "myapp://product/456",
            utmParameters: UTMParameters(source: "facebook", campaign: "summer")
        )

        var receivedData: DeepLinkData?

        // Act
        sut.onDeferredDeepLink { data in
            receivedData = data
            expectation.fulfill()
        }

        sut.deliverDeferredDeepLink(testData)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedData)
        XCTAssertEqual(receivedData?.shortCode, "abc123")
        XCTAssertEqual(receivedData?.utmParameters?.source, "facebook")
    }

    func testDeferredDeepLinkWithOrganicInstall() {
        // Arrange
        let expectation = expectation(description: "Organic install")
        var receivedData: DeepLinkData?
        var callbackInvoked = false

        // Act
        sut.onDeferredDeepLink { data in
            receivedData = data
            callbackInvoked = true
            expectation.fulfill()
        }

        sut.deliverDeferredDeepLink(nil)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(callbackInvoked)
        XCTAssertNil(receivedData)
    }

    func testDeferredDeepLinkCallbackInvokedImmediatelyIfDataCached() {
        // Arrange
        let firstExpectation = expectation(description: "First callback")
        let secondExpectation = expectation(description: "Second callback - immediate")

        let testData = DeepLinkData(shortCode: "cached123")

        // First callback
        sut.onDeferredDeepLink { _ in
            firstExpectation.fulfill()
        }

        sut.deliverDeferredDeepLink(testData)

        wait(for: [firstExpectation], timeout: 1.0)

        var receivedData: DeepLinkData?

        // Act - Register second callback after data delivered
        sut.onDeferredDeepLink { data in
            receivedData = data
            secondExpectation.fulfill()
        }

        // Assert
        wait(for: [secondExpectation], timeout: 1.0)
        XCTAssertEqual(receivedData?.shortCode, "cached123")
    }

    func testMultipleDeferredDeepLinkCallbacks() {
        // Arrange
        let expectation1 = expectation(description: "Callback 1")
        let expectation2 = expectation(description: "Callback 2")
        let expectation3 = expectation(description: "Callback 3")

        let testData = DeepLinkData(shortCode: "multi123")

        var callback1Data: DeepLinkData?
        var callback2Data: DeepLinkData?
        var callback3Data: DeepLinkData?

        // Act
        sut.onDeferredDeepLink { data in
            callback1Data = data
            expectation1.fulfill()
        }

        sut.onDeferredDeepLink { data in
            callback2Data = data
            expectation2.fulfill()
        }

        sut.onDeferredDeepLink { data in
            callback3Data = data
            expectation3.fulfill()
        }

        sut.deliverDeferredDeepLink(testData)

        // Assert
        wait(for: [expectation1, expectation2, expectation3], timeout: 1.0)
        XCTAssertEqual(callback1Data?.shortCode, "multi123")
        XCTAssertEqual(callback2Data?.shortCode, "multi123")
        XCTAssertEqual(callback3Data?.shortCode, "multi123")
    }

    // MARK: - Direct Deep Link Tests

    func testOnDeepLinkRegistersCallback() {
        // Arrange
        let expectation = expectation(description: "Deep link callback")
        let url = URL(string: "https://go.example.com/test123")!

        var callbackInvoked = false

        // Act
        sut.onDeepLink { _, _ in
            callbackInvoked = true
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(callbackInvoked)
    }

    func testHandleDeepLinkWithValidURL() {
        // Arrange
        let expectation = expectation(description: "Valid deep link")
        let url = URL(string: "https://go.example.com/abc123?utm_source=email")!

        var receivedURL: URL?
        var receivedData: DeepLinkData?

        // Act
        sut.onDeepLink { callbackURL, data in
            receivedURL = callbackURL
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedURL, url)
        XCTAssertNotNil(receivedData)
        XCTAssertEqual(receivedData?.shortCode, "abc123")
        XCTAssertEqual(receivedData?.utmParameters?.source, "email")
    }

    func testHandleDeepLinkWithInvalidURL() {
        // Arrange
        let expectation = expectation(description: "Invalid deep link")
        let url = URL(string: "https://go.example.com/")!

        var receivedData: DeepLinkData?

        // Act
        sut.onDeepLink { _, data in
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(receivedData)
    }

    func testMultipleDeepLinkCallbacks() {
        // Arrange
        let expectation1 = expectation(description: "Callback 1")
        let expectation2 = expectation(description: "Callback 2")

        let url = URL(string: "https://go.example.com/test123")!

        var callback1Invoked = false
        var callback2Invoked = false

        // Act
        sut.onDeepLink { _, _ in
            callback1Invoked = true
            expectation1.fulfill()
        }

        sut.onDeepLink { _, _ in
            callback2Invoked = true
            expectation2.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation1, expectation2], timeout: 1.0)
        XCTAssertTrue(callback1Invoked)
        XCTAssertTrue(callback2Invoked)
    }

    func testDeepLinkWithCustomScheme() {
        // Arrange
        let expectation = expectation(description: "Custom scheme")
        let url = URL(string: "myapp://product/abc123?id=456")!

        var receivedData: DeepLinkData?

        // Act
        sut.onDeepLink { _, data in
            receivedData = data
            expectation.fulfill()
        }

        sut.handleDeepLink(url)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedData?.shortCode, "abc123")
        XCTAssertEqual(receivedData?.customParameters?["id"], "456")
    }

    // MARK: - Callback Execution Tests

    func testCallbacksInvokedOnMainThread() {
        // Arrange
        let deferredExpectation = expectation(description: "Deferred on main thread")
        let directExpectation = expectation(description: "Direct on main thread")

        // Test deferred deep link
        sut.onDeferredDeepLink { _ in
            XCTAssertTrue(Thread.isMainThread, "Deferred callback should be on main thread")
            deferredExpectation.fulfill()
        }

        sut.deliverDeferredDeepLink(nil)

        // Test direct deep link
        sut.onDeepLink { _, _ in
            XCTAssertTrue(Thread.isMainThread, "Direct callback should be on main thread")
            directExpectation.fulfill()
        }

        sut.handleDeepLink(URL(string: "https://example.com/test")!)

        // Assert
        wait(for: [deferredExpectation, directExpectation], timeout: 1.0)
    }

    // MARK: - Clear Callbacks Tests

    func testClearCallbacksRemovesAll() {
        // Arrange
        sut.onDeferredDeepLink { _ in
            XCTFail("Callback should not be invoked after clear")
        }

        sut.onDeepLink { _, _ in
            XCTFail("Callback should not be invoked after clear")
        }

        // Act
        sut.clearCallbacks()

        // Give callbacks time to potentially execute
        Thread.sleep(forTimeInterval: 0.2)

        sut.deliverDeferredDeepLink(DeepLinkData(shortCode: "test"))
        sut.handleDeepLink(URL(string: "https://example.com/test")!)

        // Assert - test passes if no failures
        Thread.sleep(forTimeInterval: 0.2)
    }

    func testClearCallbacksResetsDeferredState() {
        // Arrange
        let firstExpectation = expectation(description: "First delivery")

        sut.onDeferredDeepLink { _ in
            firstExpectation.fulfill()
        }

        sut.deliverDeferredDeepLink(DeepLinkData(shortCode: "first"))
        wait(for: [firstExpectation], timeout: 1.0)

        // Act
        sut.clearCallbacks()

        let secondExpectation = expectation(description: "Second delivery")
        var callbackInvoked = false

        sut.onDeferredDeepLink { _ in
            callbackInvoked = true
            secondExpectation.fulfill()
        }

        // Should not invoke immediately because state was cleared
        Thread.sleep(forTimeInterval: 0.1)

        // Now deliver again
        sut.deliverDeferredDeepLink(DeepLinkData(shortCode: "second"))

        // Assert
        wait(for: [secondExpectation], timeout: 1.0)
        XCTAssertTrue(callbackInvoked)
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
