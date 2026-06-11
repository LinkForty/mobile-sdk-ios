//
//  AttributionContext.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// The active last-click attribution: the deep link currently credited for
/// in-app activity, and when it opened the app.
struct ActiveAttribution: Codable {
    let linkId: String
    let clickId: String?
    /// ISO 8601 timestamp of when the deep link opened the app.
    let openedAt: String
}

/// The attribution fields merged into every event payload. `sessionId` is always
/// present; the link fields are absent until a deep link has opened the app.
struct AttributionStamp {
    let attributedLinkId: String?
    let attributedClickId: String?
    let linkOpenedAt: String?
    let sessionId: String
}

/// Last-click attribution + session tracking for in-app events.
///
/// LinkForty attributes in-app activity (events, and — once auto-tracking lands —
/// screen views) to the deep link that drove it, using a last-click + window model:
///
/// - Every deep-link open (deferred install OR direct re-engagement) pins an
///   active context to THAT link. The newest open wins (supersede).
/// - Every event is stamped with the active context so the backend can credit the
///   link. Whether a stamped event still counts (the window) and how sessions are
///   grouped is decided server-side at query time — the SDK only reports the active
///   link, when it opened, and the current session.
/// - A `sessionId` identifies one app-open journey: generated on cold start and
///   rotated on each new deep-link open.
///
/// The active context is persisted (UserDefaults) so a reopen without a new click
/// still attributes to the last link (subject to the server-side conversion
/// window). The session is intentionally in-memory: a cold start is a new session.
@available(iOS 13.0, macOS 10.15, *)
final class AttributionContext {
    private let defaults: UserDefaults
    private let debug: Bool
    private let lock = NSLock()

    private var active: ActiveAttribution?
    private var sessionId: String

    init(defaults: UserDefaults = .standard, debug: Bool = false) {
        self.defaults = defaults
        self.debug = debug
        // Construction == cold start == a new session.
        self.sessionId = UUID().uuidString.lowercased()
        self.active = Self.loadActive(from: defaults)
    }

    /// Records a deep-link open. The newest open supersedes the previous one
    /// (last-click) and starts a new session. A no-op when no `linkId` is known
    /// (organic/unresolved open) — there is nothing to attribute to.
    ///
    /// - Parameters:
    ///   - linkId: The link the deep link resolved to (`DeepLinkData.linkId`).
    ///   - clickId: Optional click id (link-level attribution works without it).
    func recordDeepLinkOpen(linkId: String?, clickId: String? = nil) {
        guard let linkId = linkId else { return }

        let attribution = ActiveAttribution(
            linkId: linkId,
            clickId: clickId,
            openedAt: ISO8601DateFormatter().string(from: Date())
        )

        lock.lock()
        active = attribution
        // A new deep-link open is the start of a new attributed journey.
        sessionId = UUID().uuidString.lowercased()
        let session = sessionId
        lock.unlock()

        if let data = try? JSONEncoder().encode(attribution) {
            defaults.set(data, forKey: StorageKeys.attribution)
        }

        if debug {
            LinkFortyLogger.log("Attribution context set: link=\(linkId) session=\(session)")
        }
    }

    /// The attribution fields to merge into every event payload.
    func getStamp() -> AttributionStamp {
        lock.lock()
        defer { lock.unlock() }
        return AttributionStamp(
            attributedLinkId: active?.linkId,
            attributedClickId: active?.clickId,
            linkOpenedAt: active?.openedAt,
            sessionId: sessionId
        )
    }

    /// The current session id (one app-open journey).
    func currentSessionId() -> String {
        lock.lock()
        defer { lock.unlock() }
        return sessionId
    }

    /// Clears the persisted context and starts a fresh session (used by clearData).
    func clear() {
        lock.lock()
        active = nil
        sessionId = UUID().uuidString.lowercased()
        lock.unlock()
        defaults.removeObject(forKey: StorageKeys.attribution)
    }

    private static func loadActive(from defaults: UserDefaults) -> ActiveAttribution? {
        guard let data = defaults.data(forKey: StorageKeys.attribution) else { return nil }
        return try? JSONDecoder().decode(ActiveAttribution.self, from: data)
    }
}
