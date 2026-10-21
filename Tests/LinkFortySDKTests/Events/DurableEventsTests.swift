//
//  DurableEventsTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

/// Events kept on the device until the server has them, each with one
/// `clientEventId` for every attempt.
@available(iOS 13.0, macOS 10.15, *)
final class DurableEventsTests: XCTestCase {
    private var session: MockURLSession!
    private var store: MockUserDefaults!
    private var storage: MockStorageManager!
    private var attributionDefaults: UserDefaults!
    private var attributionSuiteName: String!

    private let eventReply = Data(#"{"eventId":"8e6c3f1e-1b2a-4c3d-9e8f-0a1b2c3d4e5f","acknowledged":true}"#.utf8)

    override func setUp() {
        super.setUp()
        session = MockURLSession()
        session.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil
        )
        session.mockData = eventReply
        store = MockUserDefaults()
        storage = MockStorageManager()
        storage.mockInstallId = "install-1"
        attributionSuiteName = "test-durable-\(UUID().uuidString)"
        attributionDefaults = UserDefaults(suiteName: attributionSuiteName)
    }

    override func tearDown() {
        attributionDefaults.removePersistentDomain(forName: attributionSuiteName)
        super.tearDown()
    }

    /// A tracker over the real network manager and a queue saved in `store`, as
    /// on a fresh launch.
    private func launchTracker() -> (EventTracker, EventQueue) {
        let queue = EventQueue(store: store)
        let tracker = EventTracker(
            networkManager: NetworkManager(
                config: LinkFortyConfig(baseURL: URL(string: "https://api.example.com")!),
                session: session
            ),
            storageManager: storage,
            attributionContext: AttributionContext(defaults: attributionDefaults),
            eventQueue: queue
        )
        return (tracker, queue)
    }

    private func sentClientEventIds() throws -> [String] {
        try session.requests.compactMap { request in
            guard let body = request.httpBody else { return nil }
            return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])["clientEventId"] as? String
        }
    }

    private func offline() {
        session.mockError = URLError(.cannotParseResponse)
    }

    private func online() {
        session.mockError = nil
        session.requests = []
    }

    func testEachEventHasALowercaseUUIDAsItsClientEventId() async throws {
        let (tracker, _) = launchTracker()

        try await tracker.trackEvent(name: "first")
        try await tracker.trackEvent(name: "second")

        let ids = try sentClientEventIds()
        XCTAssertEqual(ids.count, 2)
        XCTAssertNotEqual(ids[0], ids[1])
        for id in ids {
            XCTAssertNotNil(UUID(uuidString: id))
            XCTAssertEqual(id, id.lowercased())
        }
    }

    func testARetryCarriesTheSameClientEventId() async throws {
        let (tracker, queue) = launchTracker()
        offline()
        try await tracker.trackEvent(name: "purchase")
        let firstAttempt = try sentClientEventIds()

        online()
        await tracker.flushQueue()

        XCTAssertEqual(try sentClientEventIds(), [firstAttempt[0]])
        XCTAssertEqual(queue.count, 0)
    }

    func testAnEventIsStoredBeforeItIsSent() async throws {
        let (tracker, _) = launchTracker()
        var storedWhileSending: Int?
        session.onRequest = { [store] _ in
            storedWhileSending = store?.data(forKey: StorageKeys.eventQueue)
                .flatMap { try? JSONDecoder().decode([EventRequest].self, from: $0) }?.count
        }

        try await tracker.trackEvent(name: "purchase")

        XCTAssertEqual(storedWhileSending, 1)
        XCTAssertNil(store.data(forKey: StorageKeys.eventQueue), "sent, so no longer stored")
    }

    func testQueuedEventsSurviveARelaunchAndAreSentOnce() async throws {
        offline()
        let (firstLaunch, _) = launchTracker()
        try await firstLaunch.trackEvent(name: "purchase", properties: ["sku": "abc", "cart": ["items": 2]])
        try await firstLaunch.trackEvent(name: "signup")
        let ids = try sentClientEventIds()

        online()
        let (nextLaunch, queue) = launchTracker()
        XCTAssertEqual(queue.peek().map(\.eventName), ["purchase", "signup"])
        let cart = queue.peek().first?.eventData["cart"]?.value as? [String: Any]
        XCTAssertEqual(cart?["items"] as? Int, 2)
        await nextLaunch.flushQueue()

        XCTAssertEqual(try sentClientEventIds(), ids)
        XCTAssertEqual(queue.count, 0)
    }

    func testARejectedEventThrowsAndIsNotKept() async throws {
        let (tracker, queue) = launchTracker()
        session.mockData = Data(#"{"error":"Install event not found"}"#.utf8)
        session.statusByPath["/api/sdk/v1/event"] = 404

        do {
            try await tracker.trackEvent(name: "purchase")
            XCTFail("Expected the rejection to be thrown")
        } catch {}

        XCTAssertEqual(queue.count, 0)
        XCTAssertNil(store.data(forKey: StorageKeys.eventQueue))
    }

    func testOverlappingFlushesSendEachQueuedEventOnce() async throws {
        offline()
        let (tracker, _) = launchTracker()
        for name in ["a", "b", "c"] {
            try await tracker.trackEvent(name: name)
        }
        let queuedIds = Set(try sentClientEventIds())

        online()
        async let first: Void = tracker.flushQueue()
        async let second: Void = tracker.flushQueue()
        async let third: Void = tracker.flushQueue()
        _ = await (first, second, third)
        await tracker.flushQueue()

        let sent = try sentClientEventIds()
        XCTAssertEqual(sent.count, 3)
        XCTAssertEqual(Set(sent), queuedIds)
    }

    func testClearingTheQueueClearsTheStoredCopy() async throws {
        offline()
        let (tracker, queue) = launchTracker()
        try await tracker.trackEvent(name: "purchase")
        XCTAssertNotNil(store.data(forKey: StorageKeys.eventQueue))

        queue.clear()

        XCTAssertNil(store.data(forKey: StorageKeys.eventQueue))
        XCTAssertEqual(EventQueue(store: store).count, 0)
    }

    func testAnUnreadableStoredQueueIsDiscarded() {
        store.set(Data("not json".utf8), forKey: StorageKeys.eventQueue)

        let queue = EventQueue(store: store)

        XCTAssertEqual(queue.count, 0)
        XCTAssertNil(store.data(forKey: StorageKeys.eventQueue))
    }
}
