//
//  LinkDomainsTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

@available(iOS 13.0, macOS 10.15, *)
final class LinkDomainsTests: XCTestCase {
    private var store: MockUserDefaults!
    private let baseURL = URL(string: "https://api.example.com")!

    override func setUp() {
        super.setUp()
        store = MockUserDefaults()
    }

    private func known(_ hosts: [String]) -> LinkDomains {
        store.set(try? JSONEncoder().encode(hosts), forKey: StorageKeys.linkDomains)
        return LinkDomains(store: store, baseURL: baseURL)
    }

    private func network(status: Int, body: String) -> (NetworkManager, MockURLSession) {
        let session = MockURLSession()
        session.mockData = Data(body.utf8)
        session.mockResponse = HTTPURLResponse(url: baseURL, statusCode: status, httpVersion: nil, headerFields: nil)
        return (NetworkManager(config: LinkFortyConfig(baseURL: baseURL), session: session), session)
    }

    // MARK: - Which URLs are looked up

    func testWithKnownHostsOnlyThoseHostsAndTheBaseHostAreLookedUp() {
        let domains = known(["links.acme.com", "go.linkforty.com"])

        XCTAssertTrue(domains.shouldLookUp(URL(string: "https://links.acme.com/abc")!))
        XCTAssertTrue(domains.shouldLookUp(URL(string: "https://GO.LinkForty.com/promo/abc")!))
        XCTAssertTrue(domains.shouldLookUp(URL(string: "https://links.acme.com:443/abc")!))
        XCTAssertTrue(domains.shouldLookUp(URL(string: "http://api.example.com/abc")!))
        XCTAssertFalse(domains.shouldLookUp(URL(string: "https://acme.com/settings/abc")!))
        XCTAssertFalse(domains.shouldLookUp(URL(string: "https://evil.links.acme.com/abc")!))
    }

    func testWithUnknownHostsEveryHttpURLIsLookedUp() {
        let domains = LinkDomains(store: store, baseURL: baseURL)

        XCTAssertFalse(domains.isKnown)
        XCTAssertTrue(domains.shouldLookUp(URL(string: "https://acme.com/settings/abc")!))
        XCTAssertTrue(domains.shouldLookUp(URL(string: "http://links.acme.com/abc")!))
    }

    func testCustomSchemesAreNeverLookedUp() {
        XCTAssertFalse(LinkDomains(store: store, baseURL: baseURL).shouldLookUp(URL(string: "myapp://product/abc")!))
        XCTAssertFalse(known(["links.acme.com"]).shouldLookUp(URL(string: "myapp://links.acme.com/abc")!))
    }

    // MARK: - Refresh

    func testARefreshSavesTheHostsForTheNextLaunch() async {
        let domains = LinkDomains(store: store, baseURL: baseURL)
        let (manager, session) = network(status: 200, body: #"{"domains":["Links.Acme.com","go.linkforty.com"]}"#)

        await domains.refresh(using: manager)

        XCTAssertEqual(session.lastRequest?.url?.path, "/api/sdk/v1/link-domains")
        XCTAssertTrue(domains.isKnown)
        XCTAssertFalse(domains.shouldLookUp(URL(string: "https://acme.com/abc")!))
        let nextLaunch = LinkDomains(store: store, baseURL: baseURL)
        XCTAssertTrue(nextLaunch.isKnown)
        XCTAssertTrue(nextLaunch.shouldLookUp(URL(string: "https://links.acme.com/abc")!))
    }

    func testAnUnknownAppTokenForgetsTheHosts() async {
        let domains = known(["links.acme.com"])
        let (manager, _) = network(status: 404, body: #"{"error":"Unknown app token"}"#)

        await domains.refresh(using: manager)

        XCTAssertFalse(domains.isKnown)
        XCTAssertNil(store.data(forKey: StorageKeys.linkDomains))
    }

    func testANetworkErrorKeepsTheHosts() async {
        let domains = known(["links.acme.com"])
        let (manager, session) = network(status: 200, body: "{}")
        session.mockError = URLError(.cannotParseResponse)

        await domains.refresh(using: manager)

        XCTAssertTrue(domains.isKnown)
        XCTAssertFalse(domains.shouldLookUp(URL(string: "https://acme.com/abc")!))
    }

    // MARK: - App token header

    func testRequestsNameTheAppWhenItHasAToken() async throws {
        let session = MockURLSession()
        session.mockData = Data(#"{"domains":[]}"#.utf8)
        session.mockResponse = HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        let withToken = NetworkManager(config: LinkFortyConfig(baseURL: baseURL, appToken: "at_123"), session: session)
        let _: LinkDomainsResponse = try await withToken.request(endpoint: "/api/sdk/v1/link-domains", method: .get)
        XCTAssertEqual(session.lastRequest?.value(forHTTPHeaderField: "X-LinkForty-App-Token"), "at_123")

        let withoutToken = NetworkManager(config: LinkFortyConfig(baseURL: baseURL), session: session)
        let _: LinkDomainsResponse = try await withoutToken.request(endpoint: "/api/sdk/v1/link-domains", method: .get)
        XCTAssertNil(session.lastRequest?.value(forHTTPHeaderField: "X-LinkForty-App-Token"))
    }
}
