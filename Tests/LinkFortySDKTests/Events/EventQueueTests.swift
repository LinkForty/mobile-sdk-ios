//
//  EventQueueTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

final class EventQueueTests: XCTestCase {
    var sut: EventQueue!

    override func setUp() {
        super.setUp()
        sut = EventQueue()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Basic Queue Operations

    func testEnqueueAddsEvent() {
        // Arrange
        let event = createTestEvent(name: "test_event")

        // Act
        let success = sut.enqueue(event)

        // Assert
        XCTAssertTrue(success)
        XCTAssertEqual(sut.count, 1)
    }

    func testDequeueRemovesOldestEvent() {
        // Arrange
        let event1 = createTestEvent(name: "first")
        let event2 = createTestEvent(name: "second")

        sut.enqueue(event1)
        sut.enqueue(event2)

        // Act
        let dequeued = sut.dequeue()

        // Assert
        XCTAssertEqual(dequeued?.eventName, "first")
        XCTAssertEqual(sut.count, 1)
    }

    func testDequeueOnEmptyQueueReturnsNil() {
        // Act
        let dequeued = sut.dequeue()

        // Assert
        XCTAssertNil(dequeued)
    }

    func testFIFOOrder() {
        // Arrange
        let events = (1...5).map { createTestEvent(name: "event_\($0)") }
        events.forEach { sut.enqueue($0) }

        // Act & Assert
        for i in 1...5 {
            let dequeued = sut.dequeue()
            XCTAssertEqual(dequeued?.eventName, "event_\(i)")
        }
    }

    // MARK: - Queue Size Tests

    func testQueueSizeLimit() {
        // Arrange - Try to add 101 events (max is 100)
        for i in 1...101 {
            let event = createTestEvent(name: "event_\(i)")
            let success = sut.enqueue(event)

            if i <= 100 {
                XCTAssertTrue(success, "Event \(i) should be queued")
            } else {
                XCTAssertFalse(success, "Event \(i) should be rejected (queue full)")
            }
        }

        // Assert
        XCTAssertEqual(sut.count, 100)
        XCTAssertTrue(sut.isFull)
    }

    func testIsEmptyWhenQueueEmpty() {
        // Assert
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
    }

    func testIsNotEmptyWhenQueueHasEvents() {
        // Arrange
        sut.enqueue(createTestEvent(name: "test"))

        // Assert
        XCTAssertFalse(sut.isEmpty)
        XCTAssertEqual(sut.count, 1)
    }

    func testIsFullWhenQueueAtCapacity() {
        // Arrange - Fill queue to capacity
        for i in 1...100 {
            sut.enqueue(createTestEvent(name: "event_\(i)"))
        }

        // Assert
        XCTAssertTrue(sut.isFull)
        XCTAssertEqual(sut.count, 100)
    }

    // MARK: - Peek Tests

    func testPeekReturnsAllEventsWithoutRemoving() {
        // Arrange
        let events = (1...3).map { createTestEvent(name: "event_\($0)") }
        events.forEach { sut.enqueue($0) }

        // Act
        let peeked = sut.peek()

        // Assert
        XCTAssertEqual(peeked.count, 3)
        XCTAssertEqual(sut.count, 3) // Events should still be in queue
        XCTAssertEqual(peeked[0].eventName, "event_1")
        XCTAssertEqual(peeked[1].eventName, "event_2")
        XCTAssertEqual(peeked[2].eventName, "event_3")
    }

    func testPeekOnEmptyQueueReturnsEmptyArray() {
        // Act
        let peeked = sut.peek()

        // Assert
        XCTAssertTrue(peeked.isEmpty)
    }

    // MARK: - Clear Tests

    func testClearRemovesAllEvents() {
        // Arrange
        for i in 1...10 {
            sut.enqueue(createTestEvent(name: "event_\(i)"))
        }

        XCTAssertEqual(sut.count, 10)

        // Act
        sut.clear()

        // Assert
        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.isEmpty)
    }

    func testClearOnEmptyQueueDoesNotCrash() {
        // Act & Assert
        XCTAssertNoThrow(sut.clear())
        XCTAssertTrue(sut.isEmpty)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentEnqueue() {
        // Arrange
        let expectation = expectation(description: "Concurrent enqueue")
        expectation.expectedFulfillmentCount = 50

        // Act - Enqueue from multiple threads
        for i in 1...50 {
            DispatchQueue.global().async {
                self.sut.enqueue(self.createTestEvent(name: "event_\(i)"))
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(sut.count, 50)
    }

    func testConcurrentDequeue() {
        // Arrange
        for i in 1...20 {
            sut.enqueue(createTestEvent(name: "event_\(i)"))
        }

        let expectation = expectation(description: "Concurrent dequeue")
        expectation.expectedFulfillmentCount = 20

        // Act - Dequeue from multiple threads
        for _ in 1...20 {
            DispatchQueue.global().async {
                _ = self.sut.dequeue()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(sut.isEmpty)
    }

    func testConcurrentEnqueueAndDequeue() {
        // Arrange
        let expectation = expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 100

        // Act - Mix of enqueue and dequeue operations
        for i in 1...50 {
            DispatchQueue.global().async {
                self.sut.enqueue(self.createTestEvent(name: "event_\(i)"))
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.sut.dequeue()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        // Queue size should be somewhere between 0-50 due to race conditions
        XCTAssertGreaterThanOrEqual(sut.count, 0)
        XCTAssertLessThanOrEqual(sut.count, 50)
    }

    // MARK: - Helper Methods

    private func createTestEvent(name: String) -> EventRequest {
        EventRequest(
            installId: "test-install-id",
            eventName: name,
            eventData: [:],
            timestamp: Date()
        )
    }
}
