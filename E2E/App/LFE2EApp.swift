//
//  LFE2EApp.swift
//  LFE2E
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import LinkFortySDK
import SwiftUI

/// End-to-end test app. It integrates the SDK the way the README describes and
/// records everything the SDK hands back to `Documents/lfe2e.jsonl`, which
/// `E2E/run.mjs` reads after each step. The driver sends commands by appending
/// to `Documents/lfe2e-commands.jsonl`: iOS asks before opening an app from a
/// custom-scheme URL, so URLs can't carry them. See `E2E/README.md`.
@main
struct LFE2EApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("LinkForty E2E")
                .onOpenURL { url in Harness.shared.open(url) }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Harness.shared.start()
        return true
    }
}

/// Settings come from `Documents/lfe2e-config.json`, written by the driver after
/// install, and can be overridden for one launch with `-lfBaseURL` style launch
/// arguments. A launch from a URL has no arguments, so the file is the default.
struct HarnessConfig {
    var baseURL: String
    var apiKey: String?
    var appToken: String?
    var attributionWindowHours: Int
    /// `after`: register callbacks once `initialize` returns.
    /// `before`: register them first, as the bundled example does.
    /// `concurrent`: call `initialize` twice at once.
    var order: String
    /// Launch argument only: a URL to hand the SDK as the app starts, as
    /// `onOpenURL` does when a link cold-starts the app.
    var openURL: String?

    static func load() -> HarnessConfig {
        let file = Harness.documents.appendingPathComponent("lfe2e-config.json")
        let json = (try? Data(contentsOf: file))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let args = UserDefaults.standard

        func value(_ key: String) -> String? {
            args.string(forKey: "lf" + key.prefix(1).uppercased() + key.dropFirst()) ?? json[key] as? String
        }

        return HarnessConfig(
            baseURL: value("baseURL") ?? "http://localhost:3000",
            apiKey: value("apiKey"),
            appToken: value("appToken"),
            attributionWindowHours: Int(value("attributionWindowHours") ?? "")
                ?? json["attributionWindowHours"] as? Int ?? 168,
            order: value("order") ?? "after",
            openURL: args.string(forKey: "lfOpenURL")
        )
    }
}

final class Harness {
    static let shared = Harness()
    static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private let launchId = UUID().uuidString
    private let logQueue = DispatchQueue(label: "lfe2e.log")
    private var config = HarnessConfig.load()

    // MARK: - Log

    func log(_ event: String, _ fields: [String: Any?] = [:]) {
        var line: [String: Any] = [
            "event": event,
            "launch": launchId,
            "at": ISO8601DateFormatter().string(from: Date()),
            "thread": Thread.isMainThread ? "main" : "background",
        ]
        for (key, value) in fields { line[key] = value ?? NSNull() }

        logQueue.async {
            guard let data = try? JSONSerialization.data(withJSONObject: line) else { return }
            let url = Harness.documents.appendingPathComponent("lfe2e.jsonl")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data + Data("\n".utf8))
                try? handle.close()
            } else {
                try? (data + Data("\n".utf8)).write(to: url)
            }
        }
    }

    private func json(_ data: DeepLinkData?) -> Any? {
        guard let data, let encoded = try? JSONEncoder().encode(data) else { return nil }
        return try? JSONSerialization.jsonObject(with: encoded)
    }

    private func describe(_ error: Error) -> String {
        "\(error)"
    }

    // MARK: - Launch

    func start() {
        log("launch", [
            "arguments": Array(ProcessInfo.processInfo.arguments.dropFirst()),
            "order": config.order,
        ])
        log("isFirstLaunchBeforeInit", ["value": LinkForty.shared.isFirstLaunch()])

        if config.order == "before" {
            registerCallbacks()
        }

        if let url = config.openURL.flatMap(URL.init(string:)) {
            open(url)
        }

        startCommandPolling()

        Task {
            if config.order == "concurrent" {
                async let first: Void = initialize(label: "first")
                async let second: Void = initialize(label: "second")
                _ = await (first, second)
            } else {
                await initialize(label: "only")
            }

            if config.order != "before" {
                registerCallbacks()
            }
        }
    }

    private func sdkConfig(baseURL: String? = nil) -> LinkFortyConfig {
        LinkFortyConfig(
            baseURL: URL(string: baseURL ?? config.baseURL)!,
            apiKey: config.apiKey,
            appToken: config.appToken,
            debug: true,
            attributionWindowHours: config.attributionWindowHours
        )
    }

    private func initialize(label: String, baseURL: String? = nil) async {
        do {
            let response = try await LinkForty.shared.initialize(config: sdkConfig(baseURL: baseURL))
            log("initResult", [
                "label": label,
                "installId": response.installId,
                "attributed": response.attributed,
                "deepLinkData": json(response.deepLinkData),
            ])
        } catch {
            log("initError", ["label": label, "error": describe(error)])
        }
        log("isFirstLaunchAfterInit", ["value": LinkForty.shared.isFirstLaunch()])
    }

    private func registerCallbacks() {
        LinkForty.shared.onDeferredDeepLink { [weak self] data in
            self?.log("deferred", ["deepLinkData": self?.json(data)])
        }
        LinkForty.shared.onDeepLink { [weak self] url, data in
            self?.log("deepLink", ["url": url.absoluteString, "deepLinkData": self?.json(data)])
        }
        log("callbacksRegistered")
    }

    // MARK: - Commands

    private var commandsHandled = 0

    private func commandLines() -> [String] {
        let url = Harness.documents.appendingPathComponent("lfe2e-commands.jsonl")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    /// Runs commands appended after this launch started.
    private func startCommandPolling() {
        commandsHandled = commandLines().count
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            let lines = self.commandLines()
            guard lines.count > self.commandsHandled else { return }
            for line in lines[self.commandsHandled...] {
                guard let data = line.data(using: .utf8),
                      let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let name = command["name"] as? String else { continue }
                let query = command["query"] as? [String: String] ?? [:]
                self.log("command", ["name": name, "query": query])
                Task { await self.run(name, query) }
            }
            self.commandsHandled = lines.count
        }
    }

    // MARK: - URLs

    /// Hands a URL to the SDK, as an app's `onOpenURL` does.
    func open(_ url: URL) {
        log("openURL", ["url": url.absoluteString])
        LinkForty.shared.handleDeepLink(url: url)
    }

    private func run(_ command: String, _ query: [String: String]) async {
        switch command {
        case "handle":
            // Delivers a URL to the SDK as a Universal Link would.
            guard let target = query["url"].flatMap(URL.init(string:)) else { return }
            LinkForty.shared.handleDeepLink(url: target)

        case "track":
            let count = Int(query["count"] ?? "1") ?? 1
            for index in 0..<count {
                do {
                    try await LinkForty.shared.trackEvent(
                        name: query["name"] ?? "e2e_event",
                        properties: ["index": index, "source": "e2e"]
                    )
                    log("trackResult", ["ok": true])
                } catch {
                    log("trackResult", ["ok": false, "error": describe(error)])
                }
            }
            log("queued", ["count": LinkForty.shared.queuedEventCount])

        case "revenue":
            do {
                try await LinkForty.shared.trackRevenue(
                    amount: Decimal(string: query["amount"] ?? "9.99") ?? 9.99,
                    currency: "USD"
                )
                log("revenueResult", ["ok": true])
            } catch {
                log("revenueResult", ["ok": false, "error": describe(error)])
            }
            log("queued", ["count": LinkForty.shared.queuedEventCount])

        case "flush":
            await LinkForty.shared.flushEvents()
            log("queued", ["count": LinkForty.shared.queuedEventCount])

        case "createLink":
            let parameters = query["params"]
                .flatMap { $0.data(using: .utf8) }
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
            do {
                let result = try await LinkForty.shared.createLink(options: CreateLinkOptions(
                    templateId: query["templateId"],
                    templateSlug: query["templateSlug"],
                    deepLinkParameters: parameters,
                    title: query["title"],
                    externalUserId: query["externalUserId"]
                ))
                log("createLinkResult", [
                    "ok": true,
                    "url": result.url,
                    "shortCode": result.shortCode,
                    "linkId": result.linkId,
                    "deduplicated": result.deduplicated,
                ])
            } catch {
                log("createLinkResult", ["ok": false, "error": describe(error)])
            }

        case "state":
            log("state", [
                "installId": LinkForty.shared.getInstallId(),
                "installData": json(LinkForty.shared.getInstallData()),
                "isFirstLaunch": LinkForty.shared.isFirstLaunch(),
                "queued": LinkForty.shared.queuedEventCount,
            ])

        case "clearData":
            LinkForty.shared.clearData()
            log("cleared")

        case "reinit":
            // A retry of `initialize` in the same process, as an app would after a failure.
            await initialize(label: "retry", baseURL: query["baseURL"])

        default:
            log("unknownCommand", ["name": command])
        }
    }
}
