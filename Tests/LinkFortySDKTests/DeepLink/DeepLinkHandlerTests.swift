//
//  DeepLinkHandlerTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

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

}
