//
//  LinkFortyTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

@available(iOS 13.0, macOS 10.15, *)
final class LinkFortyTests: XCTestCase {
    var config: LinkFortyConfig!

    override func setUp() {
        super.setUp()

        // Reset singleton state before each test
        LinkForty.shared.reset()
        LinkForty.shared.clearData()

        // Create test configuration
        config = LinkFortyConfig(
            baseURL: URL(string: "https://api.linkforty.com")!,
            apiKey: "test-api-key"
        )
    }

    override func tearDown() {
        LinkForty.shared.reset()
        LinkForty.shared.clearData()
        config = nil
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstanceIsSingleton() {
        let instance1 = LinkForty.shared
        let instance2 = LinkForty.shared

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Initialization Tests

    func testInitializeThrowsForInvalidConfig() async {
        // Arrange - invalid URL with negative attribution window
        let invalidConfig = LinkFortyConfig(
            baseURL: URL(string: "https://api.linkforty.com")!,
            apiKey: "test-key",
            attributionWindowHours: -1
        )

        // Act & Assert
        do {
            _ = try await LinkForty.shared.initialize(config: invalidConfig)
            XCTFail("Should throw error for invalid config")
        } catch {
            // Expected
            XCTAssertNotNil(error)
        }
    }

    func testInitializeThrowsWhenAlreadyInitialized() async {
        // This test is skipped because we can't mock the network layer
        // in the singleton without dependency injection
        // We would need to initialize once, then try again
    }

    func testResetClearsInitializedState() {
        // Act
        LinkForty.shared.reset()

        // Assert
        XCTAssertNil(LinkForty.shared.getInstallId())
    }

    // MARK: - Deep Link Tests

    func testHandleDeepLinkBeforeInitialize() {
        // Arrange
        let url = URL(string: "https://example.com/abc123")!

        // Act - Should not crash
        LinkForty.shared.handleDeepLink(url: url)

        // Assert - Just verify no crash
        XCTAssertTrue(true)
    }

    func testOnDeferredDeepLinkBeforeInitialize() {
        // Arrange
        var callbackInvoked = false
        let callback: DeferredDeepLinkCallback = { _ in
            callbackInvoked = true
        }

        // Act
        LinkForty.shared.onDeferredDeepLink(callback)

        // Assert - Callback should not be registered before initialization
        XCTAssertFalse(callbackInvoked)
    }

    func testOnDeepLinkBeforeInitialize() {
        // Arrange
        var callbackInvoked = false
        let callback: DeepLinkCallback = { _, _ in
            callbackInvoked = true
        }

        // Act
        LinkForty.shared.onDeepLink(callback)

        // Assert - Callback should not be registered before initialization
        XCTAssertFalse(callbackInvoked)
    }

    // MARK: - Event Tracking Tests

    func testTrackEventBeforeInitializeThrows() async {
        // Act & Assert
        do {
            try await LinkForty.shared.trackEvent(name: "test")
            XCTFail("Should throw error when not initialized")
        } catch let error as LinkFortyError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testTrackRevenueBeforeInitializeThrows() async {
        // Act & Assert
        do {
            try await LinkForty.shared.trackRevenue(amount: 9.99, currency: "USD")
            XCTFail("Should throw error when not initialized")
        } catch let error as LinkFortyError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testFlushEventsBeforeInitialize() async {
        // Act - Should not crash
        await LinkForty.shared.flushEvents()

        // Assert - Just verify no crash
        XCTAssertTrue(true)
    }

    func testQueuedEventCountBeforeInitialize() {
        // Act
        let count = LinkForty.shared.queuedEventCount

        // Assert
        XCTAssertEqual(count, 0)
    }

    func testClearEventQueueBeforeInitialize() {
        // Act - Should not crash
        LinkForty.shared.clearEventQueue()

        // Assert - Just verify no crash
        XCTAssertTrue(true)
    }

    // MARK: - Attribution Data Tests

    func testGetInstallIdBeforeInitialize() {
        // Act
        let installId = LinkForty.shared.getInstallId()

        // Assert
        XCTAssertNil(installId)
    }

    func testGetInstallDataBeforeInitialize() {
        // Act
        let data = LinkForty.shared.getInstallData()

        // Assert
        XCTAssertNil(data)
    }

    func testIsFirstLaunchBeforeInitialize() {
        // Act
        let isFirst = LinkForty.shared.isFirstLaunch()

        // Assert
        XCTAssertTrue(isFirst)
    }

    // MARK: - Data Management Tests

    func testClearDataDoesNotCrash() {
        // Act & Assert
        XCTAssertNoThrow(LinkForty.shared.clearData())
    }

    func testResetDoesNotCrash() {
        // Act & Assert
        XCTAssertNoThrow(LinkForty.shared.reset())
    }

    func testClearDataThenReset() {
        // Act & Assert
        XCTAssertNoThrow(LinkForty.shared.clearData())
        XCTAssertNoThrow(LinkForty.shared.reset())
    }

    // MARK: - Configuration Validation Tests

    func testConfigWithHTTPURLThrows() async {
        // Arrange
        let httpConfig = LinkFortyConfig(
            baseURL: URL(string: "http://api.linkforty.com")!,
            apiKey: "test-key"
        )

        // Act & Assert
        do {
            _ = try await LinkForty.shared.initialize(config: httpConfig)
            XCTFail("Should throw error for HTTP URL")
        } catch {
            // Expected
            XCTAssertNotNil(error)
        }
    }

    func testConfigWithLocalhostHTTPAllowed() {
        // Arrange
        let localhostConfig = LinkFortyConfig(
            baseURL: URL(string: "http://localhost:3000")!,
            apiKey: "test-key"
        )

        // Act & Assert
        XCTAssertNoThrow(try localhostConfig.validate())
    }

    func testConfigWithInvalidAttributionWindowThrows() {
        // Arrange & Act
        let invalidConfig = LinkFortyConfig(
            baseURL: URL(string: "https://api.linkforty.com")!,
            apiKey: "test-key",
            attributionWindowHours: 3000 // Too large
        )

        // Assert
        XCTAssertThrowsError(try invalidConfig.validate())
    }

    func testConfigWithEmptyAPIKeyIsAllowedForSelfHosted() {
        // Arrange & Act - Empty API key is allowed for self-hosted
        let selfHostedConfig = LinkFortyConfig(
            baseURL: URL(string: "https://self-hosted.linkforty.com")!,
            apiKey: nil
        )

        // Assert - Should not throw for self-hosted with no API key
        XCTAssertNoThrow(try selfHostedConfig.validate())
    }

    // MARK: - Link Creation Tests

    func testCreateLinkBeforeInitializeThrows() async {
        // Act & Assert
        do {
            _ = try await LinkForty.shared.createLink(options: CreateLinkOptions())
            XCTFail("Should throw error when not initialized")
        } catch let error as LinkFortyError {
            if case .notInitialized = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentResetCalls() {
        // Arrange
        let expectation = expectation(description: "Concurrent resets")
        expectation.expectedFulfillmentCount = 10

        // Act - Reset from multiple threads
        for _ in 1...10 {
            DispatchQueue.global().async {
                LinkForty.shared.reset()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        // If we get here without crash, test passes
        XCTAssertTrue(true)
    }

    func testConcurrentClearDataCalls() {
        // Arrange
        let expectation = expectation(description: "Concurrent clear data")
        expectation.expectedFulfillmentCount = 10

        // Act - Clear data from multiple threads
        for _ in 1...10 {
            DispatchQueue.global().async {
                LinkForty.shared.clearData()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        // If we get here without crash, test passes
        XCTAssertTrue(true)
    }
}
