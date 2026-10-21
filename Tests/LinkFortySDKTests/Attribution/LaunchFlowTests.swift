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

    func testIsFirstLaunchIsFalseBeforeInitializeOnLaterLaunch() async throws {
        _ = try await launch()

        endLaunch()
        XCTAssertFalse(LinkForty.shared.isFirstLaunch())

        _ = try await LinkForty.shared.initialize(config: config)
        XCTAssertFalse(LinkForty.shared.isFirstLaunch())
    }
}
