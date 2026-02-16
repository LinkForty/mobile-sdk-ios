//
//  EventTrackerTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

@available(iOS 13.0, macOS 10.15, *)
final class EventTrackerTests: XCTestCase {
    var sut: EventTracker!
    var mockNetworkManager: MockNetworkManager!
    var mockStorageManager: MockStorageManager!
    var mockEventQueue: MockEventQueue!

    override func setUp() {
        super.setUp()
        mockNetworkManager = MockNetworkManager()
        mockStorageManager = MockStorageManager()
        mockEventQueue = MockEventQueue()

        mockStorageManager.mockInstallId = "test-install-id"

        sut = EventTracker(
            networkManager: mockNetworkManager,
            storageManager: mockStorageManager,
            eventQueue: mockEventQueue
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkManager = nil
        mockStorageManager = nil
        mockEventQueue = nil
        super.tearDown()
    }

    // MARK: - Track Event Tests

    func testTrackEventSuccess() async throws {
        // Arrange
        mockNetworkManager.mockResponse = EventResponse(success: true)

        // Act
        try await sut.trackEvent(name: "test_event", properties: ["key": "value"])

        // Assert
        XCTAssertEqual(mockNetworkManager.lastEndpoint, "/api/sdk/v1/event")
        XCTAssertEqual(mockNetworkManager.lastMethod, .post)
    }

    func testTrackEventWithoutProperties() async throws {
        // Arrange
        mockNetworkManager.mockResponse = EventResponse(success: true)

        // Act
        try await sut.trackEvent(name: "simple_event")

        // Assert
        XCTAssertNotNil(mockNetworkManager.lastBody)
    }

    func testTrackEventWithProperties() async throws {
        // Arrange
        mockNetworkManager.mockResponse = EventResponse(success: true)
        let properties = [
            "product_id": "123",
            "category": "electronics",
            "price": 99.99
        ] as [String: Any]

        // Act
        try await sut.trackEvent(name: "purchase", properties: properties)

        // Assert
        XCTAssertNotNil(mockNetworkManager.lastBody)
    }

    func testTrackEventValidatesEmptyName() async {
        // Act & Assert
        do {
            try await sut.trackEvent(name: "", properties: nil)
            XCTFail("Should throw error for empty name")
        } catch let error as LinkFortyError {
            if case .invalidEventData(let message) = error {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testTrackEventRequiresInstallId() async {
        // Arrange
        mockStorageManager.mockInstallId = nil

        // Act & Assert
        do {
            try await sut.trackEvent(name: "test")
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

    // MARK: - Track Revenue Tests

    func testTrackRevenue() async throws {
        // Arrange
        mockNetworkManager.mockResponse = EventResponse(success: true)

        // Act
        try await sut.trackRevenue(amount: 29.99, currency: "USD")

        // Assert
        XCTAssertEqual(mockNetworkManager.lastEndpoint, "/api/sdk/v1/event")
    }

    func testTrackRevenueWithProperties() async throws {
        // Arrange
        mockNetworkManager.mockResponse = EventResponse(success: true)

        // Act
        try await sut.trackRevenue(
            amount: 49.99,
            currency: "EUR",
            properties: ["product_id": "789"]
        )

        // Assert
        XCTAssertNotNil(mockNetworkManager.lastBody)
    }

    func testTrackRevenueRejectsNegativeAmount() async {
        // Act & Assert
        do {
            try await sut.trackRevenue(amount: -10.0, currency: "USD")
            XCTFail("Should throw error for negative amount")
        } catch let error as LinkFortyError {
            if case .invalidEventData(let message) = error {
                XCTAssertTrue(message.contains("non-negative"))
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testTrackRevenueAcceptsZero() async throws {
        // Arrange
        mockNetworkManager.mockResponse = EventResponse(success: true)

        // Act & Assert - Should not throw
        try await sut.trackRevenue(amount: 0, currency: "USD")

        // If we get here, test passes
        XCTAssertEqual(mockNetworkManager.lastEndpoint, "/api/sdk/v1/event")
    }

    // MARK: - Queue Tests

    func testEventQueuedOnNetworkError() async {
        // Arrange
        mockNetworkManager.mockError = LinkFortyError.networkError(
            NSError(domain: "test", code: -1)
        )

        // Act
        do {
            try await sut.trackEvent(name: "test_event")
        } catch {
            // Expected to throw
        }

        // Assert
        XCTAssertEqual(mockEventQueue.enqueuedEvents.count, 1)
        XCTAssertEqual(mockEventQueue.enqueuedEvents.first?.eventName, "test_event")
    }

    func testQueuedEventCount() {
        // Arrange
        mockEventQueue.mockCount = 5

        // Act
        let count = sut.queuedEventCount

        // Assert
        XCTAssertEqual(count, 5)
    }

    func testClearQueue() {
        // Act
        sut.clearQueue()

        // Assert
        XCTAssertTrue(mockEventQueue.clearCalled)
    }

    // MARK: - Network Error Tests

    func testTrackEventNetworkError() async {
        // Arrange
        mockNetworkManager.mockError = LinkFortyError.networkError(
            NSError(domain: "test", code: -1)
        )

        // Act & Assert
        do {
            try await sut.trackEvent(name: "test")
            XCTFail("Should throw error")
        } catch {
            // Expected
            XCTAssertNotNil(error)
        }
    }

    func testTrackEventServerError() async {
        // Arrange
        mockNetworkManager.mockError = LinkFortyError.invalidResponse(
            statusCode: 500,
            message: "Server error"
        )

        // Act & Assert
        do {
            try await sut.trackEvent(name: "test")
            XCTFail("Should throw error")
        } catch {
            // Expected
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mock Event Queue

class MockEventQueue: EventQueue {
    var enqueuedEvents: [EventRequest] = []
    var clearCalled = false
    var mockCount = 0

    override func enqueue(_ event: EventRequest) -> Bool {
        enqueuedEvents.append(event)
        return true
    }

    override func clear() {
        clearCalled = true
        enqueuedEvents.removeAll()
    }

    override var count: Int {
        mockCount > 0 ? mockCount : enqueuedEvents.count
    }
}
