//
//  LaunchFlowTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

/// `initialize()` across launches. Each launch is `reset()` followed by
/// `initialize()` over the same storage, as when the app is killed and reopened.
@available(iOS 13.0, macOS 10.15, *)
final class LaunchFlowTests: XCTestCase {
    private var defaults: MockUserDefaults!
    private var session: MockURLSession!
    private let config = LinkFortyConfig(baseURL: URL(string: "https://api.example.com")!)

    override func setUp() {
        super.setUp()
        LinkForty.shared.reset()

        defaults = MockUserDefaults()
        session = MockURLSession()
        session.mockData = try? JSONEncoder().encode(
            InstallResponse(
                installId: "install-1",
                attributed: true,
                confidenceScore: 90,
                matchedFactors: ["ip", "userAgent"],
                deepLinkData: DeepLinkData(shortCode: "welcome", iosURL: "myapp://welcome")
            )
        )
        session.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/api/sdk/v1/install")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        LinkForty.shared.userDefaults = defaults
        LinkForty.shared.urlSession = session
    }

    override func tearDown() {
        LinkForty.shared.reset()
        LinkForty.shared.userDefaults = UserDefaults.standard
        LinkForty.shared.urlSession = URLSession.shared
        defaults = nil
        session = nil
        super.tearDown()
    }

    /// Ends the current launch. `StorageManager` writes on its own serial queue,
    /// and the next launch reads through a new manager; a read on the current
    /// manager drains its queue first, so the next launch sees what this one stored.
    private func endLaunch() {
        _ = LinkForty.shared.getInstallId()
        LinkForty.shared.reset()
    }

    /// Initializes the SDK and returns the deferred deep links delivered on this launch.
    private func launch() async throws -> (response: InstallResponse, deferred: [DeepLinkData?]) {
        endLaunch()
        let response = try await LinkForty.shared.initialize(config: config)

        var deferred: [DeepLinkData?] = []
        LinkForty.shared.onDeferredDeepLink { deferred.append($0) }

        // Callbacks run on the main queue after the handler's queue; let both drain.
        try await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {}

        return (response, deferred)
    }

    func testFirstLaunchReportsInstallAndDeliversDeferredDeepLink() async throws {
        let first = try await launch()

        XCTAssertEqual(session.lastRequest?.url?.path, "/api/sdk/v1/install")
        XCTAssertEqual(first.response.installId, "install-1")
        XCTAssertEqual(first.deferred.count, 1)
        XCTAssertEqual(first.deferred.first??.shortCode, "welcome")
    }

    func testLaterLaunchReportsNoInstallAndDeliversNoDeferredDeepLink() async throws {
        _ = try await launch()
        session.lastRequest = nil

        let second = try await launch()

        XCTAssertNil(session.lastRequest, "a later launch must not report another install")
        XCTAssertEqual(second.response.installId, "install-1")
        XCTAssertTrue(second.response.attributed)
        XCTAssertEqual(second.response.deepLinkData?.shortCode, "welcome")
        XCTAssertTrue(second.deferred.isEmpty, "a later launch must not deliver the deferred deep link again")
        XCTAssertEqual(LinkForty.shared.getInstallData()?.shortCode, "welcome")
    }

    func testFailedInstallReportIsRetriedOnNextLaunch() async throws {
        session.mockError = URLError(.notConnectedToInternet)
        LinkForty.shared.reset()
        do {
            _ = try await LinkForty.shared.initialize(config: config)
            XCTFail("Expected initialize to throw")
        } catch {}

        session.mockError = nil
        let next = try await launch()

        XCTAssertEqual(session.lastRequest?.url?.path, "/api/sdk/v1/install")
        XCTAssertEqual(next.deferred.count, 1)
    }

    func testIsFirstLaunchIsTrueBeforeAndAfterInitializeOnFirstLaunch() async throws {
        LinkForty.shared.reset()
        XCTAssertTrue(LinkForty.shared.isFirstLaunch())

        _ = try await LinkForty.shared.initialize(config: config)

        XCTAssertTrue(LinkForty.shared.isFirstLaunch())
    }

    func testOrganicInstallDeliversNilOnce() async throws {
        session.mockData = try JSONEncoder().encode(
            InstallResponse(installId: "install-1", attributed: false, confidenceScore: 0, matchedFactors: [])
        )

        let first = try await launch()
        let second = try await launch()

        XCTAssertEqual(first.deferred.count, 1)
        XCTAssertNil(first.deferred.first ?? DeepLinkData(shortCode: "not delivered"))
        XCTAssertTrue(second.deferred.isEmpty)
    }

    func testCallbacksRegisteredBeforeInitializeReceiveTheDeferredDeepLink() async throws {
        endLaunch()
        var deferred: [DeepLinkData?] = []
        LinkForty.shared.onDeferredDeepLink { deferred.append($0) }

        _ = try await LinkForty.shared.initialize(config: config)
        try await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {}

        XCTAssertEqual(deferred.count, 1)
        XCTAssertEqual(deferred.first??.shortCode, "welcome")
    }

    func testLinkHandledBeforeInitializeIsDeliveredOnceInitialized() async throws {
        endLaunch()
        var opened: [URL] = []
        LinkForty.shared.onDeepLink { url, _ in opened.append(url) }
        let link = URL(string: "https://go.example.com/abc123")!

        LinkForty.shared.handleDeepLink(url: link)
        XCTAssertTrue(opened.isEmpty)
        _ = try await LinkForty.shared.initialize(config: config)
        try await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {}

        XCTAssertEqual(opened, [link])
    }

    func testFailedInitializeCanBeRetriedInTheSameLaunch() async throws {
        endLaunch()
        session.queuedErrors = [URLError(.cannotParseResponse)]
        do {
            _ = try await LinkForty.shared.initialize(config: config)
            XCTFail("Expected initialize to throw")
        } catch {}

        let response = try await LinkForty.shared.initialize(config: config)

        XCTAssertEqual(response.installId, "install-1")
        XCTAssertEqual(LinkForty.shared.getInstallId(), "install-1")
    }

    func testConfiguredAttributionWindowIsSent() async throws {
        endLaunch()

        _ = try await LinkForty.shared.initialize(
            config: LinkFortyConfig(baseURL: URL(string: "https://api.example.com")!, attributionWindowHours: 24)
        )

        let body = try XCTUnwrap(session.lastRequest?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["attributionWindowHours"] as? Int, 24)
    }

    func testClearDataKeepsDeepLinkCallbacks() async throws {
        _ = try await launch()
        var opened: [URL] = []
        LinkForty.shared.onDeepLink { url, _ in opened.append(url) }
        let link = URL(string: "https://go.example.com/abc123")!

        LinkForty.shared.clearData()
        LinkForty.shared.handleDeepLink(url: link)
        try await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {}

        XCTAssertEqual(opened, [link])
    }

    private func initializeWithApiKey() async throws {
        endLaunch()
        _ = try await LinkForty.shared.initialize(
            config: LinkFortyConfig(baseURL: URL(string: "https://api.example.com")!, apiKey: "key")
        )
    }

    private func requestBody(path: String) throws -> [String: Any] {
        let request = try XCTUnwrap(session.requests.last { $0.url?.path == path })
        return try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    func testCreateLinkWithTemplateUsesTheSDKEndpointAndKeepsTheUser() async throws {
        session.dataByPath["/api/sdk/v1/links"] = Data(
            #"{"url":"https://links.example.com/promo/abc","shortCode":"abc","linkId":"link-1","deduplicated":false}"#.utf8
        )
        try await initializeWithApiKey()
        LinkForty.shared.setExternalUserId("user-1")

        let result = try await LinkForty.shared.createLink(
            options: CreateLinkOptions(templateId: "template-1", templateSlug: "promo")
        )

        let body = try requestBody(path: "/api/sdk/v1/links")
        XCTAssertEqual(body["templateId"] as? String, "template-1")
        XCTAssertEqual(body["externalUserId"] as? String, "user-1")
        XCTAssertEqual(result.url, "https://links.example.com/promo/abc")
        XCTAssertFalse(session.requests.contains { $0.url?.path == "/api/links" })
    }

    func testCreateLinkFallsBackWhenTheServerHasNoSDKEndpoint() async throws {
        session.statusByPath["/api/sdk/v1/links"] = 404
        session.dataByPath["/api/sdk/v1/links"] = Data(#"{"error":"Not Found"}"#.utf8)
        session.dataByPath["/api/links"] = Data(
            #"{"id":"link-1","short_code":"abc","short_url":"https://links.example.com/promo/abc"}"#.utf8
        )
        try await initializeWithApiKey()

        let result = try await LinkForty.shared.createLink(
            options: CreateLinkOptions(templateId: "template-1", templateSlug: "promo")
        )

        XCTAssertEqual(result.url, "https://links.example.com/promo/abc")
        XCTAssertEqual(result.linkId, "link-1")
    }

    func testCreateLinkDoesNotFallBackOnOtherErrors() async throws {
        session.statusByPath["/api/sdk/v1/links"] = 400
        session.dataByPath["/api/sdk/v1/links"] = Data(#"{"error":"Bad Request"}"#.utf8)
        try await initializeWithApiKey()

        do {
            _ = try await LinkForty.shared.createLink(options: CreateLinkOptions(templateId: "template-1"))
            XCTFail("Expected the error to be thrown")
        } catch {}

        XCTAssertFalse(session.requests.contains { $0.url?.path == "/api/links" })
    }

    func testIsFirstLaunchIsFalseBeforeInitializeOnLaterLaunch() async throws {
        _ = try await launch()

        endLaunch()
        XCTAssertFalse(LinkForty.shared.isFirstLaunch())

        _ = try await LinkForty.shared.initialize(config: config)
        XCTAssertFalse(LinkForty.shared.isFirstLaunch())
    }
}
