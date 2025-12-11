//
//  BasicExampleApp.swift
//  BasicExample
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import SwiftUI
import LinkFortySDK

@available(iOS 14.0, *)
@main
struct BasicExampleApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    // Handle deep links
                    LinkForty.shared.handleDeepLink(url: url)
                }
        }
    }
}

@available(iOS 13.0, *)
class AppState: ObservableObject {
    @Published var installId: String?
    @Published var isAttributed: Bool = false
    @Published var deepLinkData: DeepLinkData?
    @Published var eventCount: Int = 0
    @Published var queuedEvents: Int = 0
    @Published var isInitialized: Bool = false
    @Published var errorMessage: String?

    init() {
        initializeSDK()
    }

    private func initializeSDK() {
        Task { @MainActor in
            do {
                // Configure SDK
                let config = LinkFortyConfig(
                    baseURL: URL(string: "https://api.linkforty.com")!,
                    apiKey: "your-api-key-here",
                    debug: true
                )

                // Register callbacks before initialization
                LinkForty.shared.onDeferredDeepLink { [weak self] data in
                    DispatchQueue.main.async {
                        self?.deepLinkData = data
                        print("📱 Deferred deep link received: \(String(describing: data))")
                    }
                }

                LinkForty.shared.onDeepLink { [weak self] url, data in
                    DispatchQueue.main.async {
                        self?.deepLinkData = data
                        print("🔗 Deep link opened: \(url)")
                        print("   Data: \(String(describing: data))")
                    }
                }

                // Initialize SDK
                let response = try await LinkForty.shared.initialize(config: config)

                // Update state
                self.installId = response.installId
                self.isAttributed = response.attributed
                self.isInitialized = true

                print("✅ SDK initialized successfully")
                print("   Install ID: \(response.installId)")
                print("   Attributed: \(response.attributed)")

                if response.attributed {
                    print("   Confidence: \(response.confidenceScore)%")
                    print("   Matched factors: \(response.matchedFactors)")
                }

            } catch {
                self.errorMessage = error.localizedDescription
                print("❌ SDK initialization failed: \(error)")
            }
        }
    }

    func trackEvent(name: String) {
        Task { @MainActor in
            do {
                try await LinkForty.shared.trackEvent(
                    name: name,
                    properties: [
                        "timestamp": Date().timeIntervalSince1970,
                        "source": "example_app"
                    ]
                )

                eventCount += 1
                queuedEvents = LinkForty.shared.queuedEventCount

                print("✅ Event tracked: \(name)")

            } catch {
                errorMessage = error.localizedDescription
                print("❌ Event tracking failed: \(error)")
            }
        }
    }

    func trackRevenue(amount: Decimal, currency: String) {
        Task { @MainActor in
            do {
                try await LinkForty.shared.trackRevenue(
                    amount: amount,
                    currency: currency,
                    properties: [
                        "product": "example_product",
                        "quantity": 1
                    ]
                )

                eventCount += 1
                queuedEvents = LinkForty.shared.queuedEventCount

                print("✅ Revenue tracked: \(amount) \(currency)")

            } catch {
                errorMessage = error.localizedDescription
                print("❌ Revenue tracking failed: \(error)")
            }
        }
    }

    func flushEvents() {
        Task { @MainActor in
            await LinkForty.shared.flushEvents()
            queuedEvents = LinkForty.shared.queuedEventCount
            print("✅ Events flushed")
        }
    }

    func clearData() {
        LinkForty.shared.clearData()
        installId = nil
        isAttributed = false
        deepLinkData = nil
        eventCount = 0
        queuedEvents = 0
        print("✅ Data cleared")
    }
}
