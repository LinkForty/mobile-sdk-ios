//
//  AttributionContextTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

@available(iOS 13.0, macOS 10.15, *)
final class AttributionContextTests: XCTestCase {
    var defaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test-attribution-context-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshContextHasSessionButNoLink() {
        let context = AttributionContext(defaults: defaults)
        let stamp = context.getStamp()

        XCTAssertFalse(stamp.sessionId.isEmpty)
        XCTAssertNil(stamp.attributedLinkId)
        XCTAssertNil(stamp.attributedClickId)
        XCTAssertNil(stamp.linkOpenedAt)
    }

    func testRecordDeepLinkOpenStampsTheLink() {
        let context = AttributionContext(defaults: defaults)
        context.recordDeepLinkOpen(linkId: "link-A", clickId: "click-1")

        let stamp = context.getStamp()
        XCTAssertEqual(stamp.attributedLinkId, "link-A")
        XCTAssertEqual(stamp.attributedClickId, "click-1")
        XCTAssertNotNil(stamp.linkOpenedAt)
    }

    func testNewOpenSupersedesAndRotatesSession() {
        let context = AttributionContext(defaults: defaults)
        context.recordDeepLinkOpen(linkId: "link-A")
        let first = context.getStamp()

        context.recordDeepLinkOpen(linkId: "link-B")
        let second = context.getStamp()

        XCTAssertEqual(second.attributedLinkId, "link-B") // newest wins
        XCTAssertNotEqual(second.sessionId, first.sessionId) // session rotates
    }

    func testOrganicOpenIsNoOp() {
        let context = AttributionContext(defaults: defaults)
        context.recordDeepLinkOpen(linkId: "link-A")
        let sessionAfterLink = context.getStamp().sessionId

        // An unresolved/organic open (no linkId) must not change anything.
        context.recordDeepLinkOpen(linkId: nil)
        let stamp = context.getStamp()

        XCTAssertEqual(stamp.attributedLinkId, "link-A")
        XCTAssertEqual(stamp.sessionId, sessionAfterLink)
    }

    func testActiveContextPersistsAcrossInstances() {
        let first = AttributionContext(defaults: defaults)
        first.recordDeepLinkOpen(linkId: "link-A")

        // A new instance (cold start) restores the link but starts a new session.
        let second = AttributionContext(defaults: defaults)
        let stamp = second.getStamp()

        XCTAssertEqual(stamp.attributedLinkId, "link-A")
        XCTAssertNotEqual(stamp.sessionId, first.getStamp().sessionId)
    }

    func testClearRemovesLinkAndRotatesSession() {
        let context = AttributionContext(defaults: defaults)
        context.recordDeepLinkOpen(linkId: "link-A")
        let before = context.getStamp().sessionId

        context.clear()
        let stamp = context.getStamp()

        XCTAssertNil(stamp.attributedLinkId)
        XCTAssertNotEqual(stamp.sessionId, before)

        // Cleared state must not be restored by a new instance.
        let reopened = AttributionContext(defaults: defaults)
        XCTAssertNil(reopened.getStamp().attributedLinkId)
    }
}
