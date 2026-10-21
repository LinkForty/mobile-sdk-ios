//
//  LinkDomains.swift
//  LinkFortySDK
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import Foundation

/// The hosts the app's workspace serves links on, which decide whether a URL is
/// looked up as a LinkForty link.
///
/// Learned from `GET /api/sdk/v1/link-domains` with the app token, and saved, so
/// a later launch knows them before the refresh finishes. Unknown without an
/// app token, or on a server without the endpoint; then every `http(s)` URL is
/// looked up, as before.
@available(iOS 13.0, macOS 10.15, *)
final class LinkDomains {
    private let store: UserDefaultsProtocol
    private let baseHost: String?
    private let lock = NSLock()
    private var hosts: Set<String>?

    init(store: UserDefaultsProtocol, baseURL: URL) {
        self.store = store
        self.baseHost = baseURL.host?.lowercased()
        if let data = store.data(forKey: StorageKeys.linkDomains),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            hosts = Set(saved)
        }
    }

    /// Whether the hosts are known, from a saved list or a refresh.
    var isKnown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hosts != nil
    }

    /// Whether `url` is looked up as a LinkForty link: an `http(s)` URL on the
    /// base URL's host or a workspace link host, or any `http(s)` URL while the
    /// hosts are unknown. Other schemes never are.
    func shouldLookUp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased() else {
            return false
        }
        if host == baseHost { return true }
        lock.lock()
        defer { lock.unlock() }
        guard let hosts else { return true }
        return hosts.contains(host)
    }

    /// Refreshes the hosts in the background when the app has a token, and hands
    /// links held before `initialize()` to `handler`. Held links wait for the
    /// first fetch, at most 3 seconds, when no list was saved on an earlier launch.
    func start(appToken: String?, network: NetworkManagerProtocol, held: [URL], handler: DeepLinkHandler) {
        let refresh = appToken == nil ? nil : Task { await self.refresh(using: network) }
        guard !held.isEmpty else { return }
        let waitFor = isKnown ? nil : refresh
        Task {
            if let waitFor { await Self.wait(for: waitFor, upTo: 3) }
            held.forEach { handler.handleDeepLink($0, lookUp: self.shouldLookUp($0)) }
        }
    }

    /// Waits for `task` to finish, or `seconds` to pass, whichever is first.
    private static func wait(for task: Task<Void, Never>, upTo seconds: Double) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await task.value }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            await group.next()
            group.cancelAll()
        }
    }

    /// Fetches the hosts. A 2xx replaces the saved list; a 4xx (no such app
    /// token, or a server without the endpoint) forgets it; a network or server
    /// error keeps what is known.
    func refresh(using networkManager: NetworkManagerProtocol) async {
        do {
            let response: LinkDomainsResponse = try await networkManager.request(
                endpoint: "/api/sdk/v1/link-domains",
                method: .get,
                body: nil,
                headers: nil
            )
            update(Set(response.domains.map { $0.lowercased() }))
        } catch LinkFortyError.invalidResponse(let statusCode?, _) where (400..<500).contains(statusCode) {
            LinkFortyLogger.log("Link domains unavailable (\(statusCode)); looking up every http(s) link")
            update(nil)
        } catch {
            LinkFortyLogger.log("Link domains refresh failed, keeping what is known: \(error)")
        }
    }

    private func update(_ newHosts: Set<String>?) {
        lock.lock()
        hosts = newHosts
        lock.unlock()
        if let newHosts, let data = try? JSONEncoder().encode(newHosts.sorted()) {
            store.set(data, forKey: StorageKeys.linkDomains)
        } else {
            store.removeObject(forKey: StorageKeys.linkDomains)
        }
    }
}

/// Reply of `GET /api/sdk/v1/link-domains`.
struct LinkDomainsResponse: Decodable {
    let domains: [String]
}
