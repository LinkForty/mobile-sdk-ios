//
//  ServerContractTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

/// Requests and responses in the shapes a LinkForty server actually sends,
/// decoded through the real `NetworkManager` rather than typed mocks.
@available(iOS 13.0, macOS 10.15, *)
final class ServerContractTests: XCTestCase {
    private var session: MockURLSession!
    private var networkManager: NetworkManager!
    private var storage: MockStorageManager!
    private var queue: EventQueue!
    private var tracker: EventTracker!
    private var attributionDefaults: UserDefaults!
    private var attributionSuiteName: String!

    /// The event endpoint's reply.
    private let eventReply = Data(#"{"eventId":"8e6c3f1e-1b2a-4c3d-9e8f-0a1b2c3d4e5f","acknowledged":true}"#.utf8)

    override func setUp() {
        super.setUp()
        session = MockURLSession()
        session.mockResponse = response(status: 200)
        networkManager = NetworkManager(
            config: LinkFortyConfig(baseURL: URL(string: "https://api.example.com")!),
            session: session
        )
        storage = MockStorageManager()
        storage.mockInstallId = "install-1"
        queue = EventQueue()
        attributionSuiteName = "test-contract-\(UUID().uuidString)"
        attributionDefaults = UserDefaults(suiteName: attributionSuiteName)
        tracker = EventTracker(
            networkManager: networkManager,
            storageManager: storage,
            attributionContext: AttributionContext(defaults: attributionDefaults),
            eventQueue: queue
        )
    }

    override func tearDown() {
        attributionDefaults.removePersistentDomain(forName: attributionSuiteName)
        super.tearDown()
    }

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - Events

    func testEventReplyDecodes() async throws {
        session.mockData = eventReply

        let reply: EventResponse = try await networkManager.request(endpoint: "/api/sdk/v1/event", method: .post)

        XCTAssertEqual(reply.acknowledged, true)
    }

    func testTrackEventSucceedsAndQueuesNothing() async throws {
        session.mockData = eventReply

        try await tracker.trackEvent(name: "purchase")

        XCTAssertEqual(session.requests.count, 1)
        XCTAssertEqual(queue.count, 0)
    }

    func testFlushSendsEachQueuedEventOnce() async throws {
        session.mockError = URLError(.cannotParseResponse)
        for name in ["first", "second"] {
            try? await tracker.trackEvent(name: name)
        }
        XCTAssertEqual(queue.count, 2)

        session.mockError = nil
        session.mockData = eventReply
        session.requests = []
        await tracker.flushQueue()
        await tracker.flushQueue()

        XCTAssertEqual(session.requests.count, 2, "each queued event is sent once")
        XCTAssertEqual(queue.count, 0)
    }

    func testFlushKeepsEventsInOrderWhenStillOffline() async throws {
        session.mockError = URLError(.cannotParseResponse)
        for name in ["first", "second"] {
            try? await tracker.trackEvent(name: name)
        }

        await tracker.flushQueue()

        XCTAssertEqual(queue.peek().map(\.eventName), ["first", "second"])
    }

    func testRejectedEventIsNotQueued() async {
        session.mockData = Data(#"{"error":"Install not found"}"#.utf8)
        session.mockResponse = response(status: 404)

        do {
            try await tracker.trackEvent(name: "purchase")
            XCTFail("Expected the rejection to be thrown")
        } catch {}

        XCTAssertEqual(queue.count, 0)
    }

    // MARK: - Network

    func testTransientNetworkErrorIsRetried() async throws {
        session.queuedErrors = [URLError(.timedOut)]
        session.mockData = eventReply

        let _: EventResponse = try await networkManager.request(endpoint: "/api/sdk/v1/event", method: .post)

        XCTAssertEqual(session.requests.count, 2)
    }

    func testCancellationIsNotWrappedOrRetried() async {
        session.mockError = CancellationError()

        do {
            let _: EventResponse = try await networkManager.request(endpoint: "/api/sdk/v1/event", method: .post)
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        XCTAssertEqual(session.requests.count, 1)
    }

    // MARK: - Deep link data

    func testParametersOfAnyTypeAreDeliveredAsStrings() throws {
        let json = #"""
        {"shortCode":"abc","customParameters":{"id":42,"premium":true,"price":9.5,"name":"x",
         "tags":["a"],"meta":{"k":"v"},"none":null}}
        """#

        let data = try JSONDecoder().decode(DeepLinkData.self, from: Data(json.utf8))

        XCTAssertEqual(data.customParameters, [
            "id": "42",
            "premium": "true",
            "price": "9.5",
            "name": "x",
            "tags": #"["a"]"#,
            "meta": #"{"k":"v"}"#
        ])
    }

    func testInstallReplyKeepsDeepLinkWithNumericParameters() throws {
        let json = #"""
        {"installId":"i1","attributed":true,"confidenceScore":70,"matchedFactors":["ip"],
         "deepLinkData":{"shortCode":"abc","customParameters":{"productId":42}}}
        """#

        let reply = try JSONDecoder().decode(InstallResponse.self, from: Data(json.utf8))

        XCTAssertEqual(reply.deepLinkData?.customParameters?["productId"], "42")
    }

    func testClickedAtWithMillisecondsIsParsed() throws {
        let json = #"{"shortCode":"abc","clickedAt":"2026-10-20T22:14:23.617Z"}"#

        let data = try JSONDecoder().decode(DeepLinkData.self, from: Data(json.utf8))

        XCTAssertEqual(data.clickedAt?.timeIntervalSince1970 ?? 0, 1_792_534_463.617, accuracy: 0.001)
    }

    func testClickedAtWithoutMillisecondsIsParsed() throws {
        let json = #"{"shortCode":"abc","clickedAt":"2026-10-20T22:14:23Z"}"#

        let data = try JSONDecoder().decode(DeepLinkData.self, from: Data(json.utf8))

        XCTAssertNotNil(data.clickedAt)
    }
}
