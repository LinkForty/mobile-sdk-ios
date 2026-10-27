# LinkForty iOS SDK

Native iOS SDK for [LinkForty](https://github.com/LinkForty/core) — the open-source alternative to Branch.io, AppsFlyer OneLink, and Firebase Dynamic Links. Add deferred deep linking, mobile attribution, and smart link routing to your iOS app. Self-hosted, privacy-first, no per-click pricing. 100% Swift with modern async/await APIs.

[![Latest Release](https://img.shields.io/github/v/release/LinkForty/mobile-sdk-ios?label=latest)](https://github.com/LinkForty/mobile-sdk-ios/releases/latest)
[![Swift Version](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://www.apple.com/ios)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)

## Features

- **Deferred Deep Linking**: Match app installs to link clicks using privacy-compliant fingerprinting
- **Universal Links**: Full support for iOS Universal Links (HTTPS deep links)
- **Custom URL Schemes**: Handle custom app URL schemes
- **Event Tracking**: Track in-app events and conversions
- **Last-Click Attribution**: In-app events are automatically credited to the deep link that most recently opened the app
- **Screen-Flow Tracking**: Report screen views to see what users do after clicking a link
- **Offline Support**: Events are kept on the device until the server has them, sent on the next launch or return to the foreground, and stored once however often they are retried
- **Privacy-First**: No IDFA, no App Tracking Transparency prompt, ships a privacy manifest
- **Programmatic Link Creation**: Create short links directly from your app
- **Zero Dependencies**: Lightweight, no third-party dependencies
- **Swift-Native**: 100% Swift, modern async/await APIs

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

The SDK is distributed with Swift Package Manager only. There is no CocoaPods pod or Carthage build.

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/LinkForty/mobile-sdk-ios.git", from: "1.8.0")
]
```

Or in Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/LinkForty/mobile-sdk-ios.git`
3. Select version and add the `LinkFortySDK` library to your app target

## Quick Start

### 1. Initialize the SDK

Initialize once at launch, in your `AppDelegate` or `@main` App struct:

```swift
import LinkFortySDK

// In AppDelegate
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Task {
        do {
            let config = LinkFortyConfig(
                baseURL: URL(string: "https://api.linkforty.com")!, // or your self-hosted server
                appToken: "at_a1b2c3d4...",     // Required on the hosted service
                debug: true
            )
            try await LinkForty.shared.initialize(config: config)
        } catch {
            print("LinkForty initialization failed: \(error)")
        }
    }
    return true
}
```

`LinkFortyConfig` fields:

| Field | Default | Description |
|-------|---------|-------------|
| `baseURL` | (required) | The LinkForty API server: `https://api.linkforty.com` on the hosted service, or your own server's URL. Must be HTTPS (HTTP is allowed only for `localhost`). |
| `appToken` | `nil` | Your workspace's public app token (`at_...`). **Required on the hosted service**: it limits install matching and link lookups to your workspace's links and lets organic installs be counted. Safe to ship in the app bundle. A self-hosted Core server does not use it. |
| `apiKey` | `nil` | Only needed for [`createLink`](#6-create-links-programmatically). It is a secret: leave it out unless the app creates links. |
| `debug` | `false` | Logs requests and SDK decisions to the console. |
| `attributionWindowHours` | `168` (7 days) | How far back an install may be matched to a click, 1 to 2160 hours. |

If the install can't be reported (for example, the device is offline on first launch), `initialize` throws and leaves the SDK uninitialized, so you can call it again later. Register `onDeferredDeepLink` and `onDeepLink` before or after `initialize`; callbacks registered first are kept.

### 2. Handle Deferred Deep Links (Install Attribution)

```swift
LinkForty.shared.onDeferredDeepLink { deepLinkData in
    if let data = deepLinkData {
        // User installed from a link - navigate to content
        print("Install attributed to: \(data.shortCode)")
        print("UTM Source: \(data.utmParameters?.source ?? "none")")

        // Navigate to the right content
        if let productId = data.customParameters?["productId"] {
            navigateToProduct(id: productId)
        }
    } else {
        // Organic install - no attribution
        print("Organic install")
    }
}
```

A deferred deep link also says how sure the match is: `confidenceScore` (0-100), `matchedFactors`, `attributionMethod` and `competingLinks`. `competingLinks` counts the other links that had a click from the same network and also reached the confidence threshold. At 0 nothing else was in contention; above 0, another device's tap may be what led to this install, so before acting on a sensitive link (a sign-in or a gift, say) treat the match as unverified, for example by asking the user to confirm:

```swift
LinkForty.shared.onDeferredDeepLink { deepLinkData in
    guard let data = deepLinkData else { return }
    if (data.competingLinks ?? 0) > 0 {
        askUserToConfirm(data)   // another link was in contention
    } else {
        redeem(data)
    }
}
```

These fields are set only on a deferred deep link from a server that sends them; they are `nil` on a direct open.

### 3. Handle Direct Deep Links (Universal Links)

First, enable Associated Domains in your Xcode project:
1. Select your target > Signing & Capabilities
2. Add "Associated Domains"
3. Add one entry per host your links are served on, for example `applinks:go.yourdomain.com`. This is the link domain in your short links, not the API `baseURL`. See [Universal Links Setup](#universal-links-setup).

The SDK does not observe incoming links by itself: the app passes each URL to `handleDeepLink(url:)`. Where iOS delivers the URL depends on your app's lifecycle, so wire every entry point your app uses.

**SwiftUI** (`App` lifecycle): `.onOpenURL` receives both Universal Links and custom-scheme URLs, including the one that launched the app:

```swift
WindowGroup {
    ContentView()
        .onOpenURL { url in
            LinkForty.shared.handleDeepLink(url: url)
        }
}
```

If the app also has an `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` handler, Universal Links go there instead of `.onOpenURL`: pass `userActivity.webpageURL` to `handleDeepLink` from it.

**UIKit with a `SceneDelegate`**: links that launch the app arrive in `scene(_:willConnectTo:options:)`; links that arrive while it runs come through `scene(_:continue:)` (Universal Links) and `scene(_:openURLContexts:)` (custom schemes). The `AppDelegate` methods below are not called in a scene-based app.

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // ... your window setup ...
    if let url = connectionOptions.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL {
        LinkForty.shared.handleDeepLink(url: url)
    }
    if let url = connectionOptions.urlContexts.first?.url {
        LinkForty.shared.handleDeepLink(url: url)
    }
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    LinkForty.shared.handleDeepLink(url: url)
}

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
        LinkForty.shared.handleDeepLink(url: url)
    }
}
```

**UIKit without scenes** (`AppDelegate` only):

```swift
// Universal Links
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return false
    }

    LinkForty.shared.handleDeepLink(url: url)
    return true
}

// Custom URL schemes
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    LinkForty.shared.handleDeepLink(url: url)
    return true
}
```

A URL passed in before `initialize` finishes (as when a link launches the app) is held and handled once the SDK is initialized.

Then register a callback to receive the link data:

```swift
LinkForty.shared.onDeepLink { url, deepLinkData in
    print("Deep link opened: \(url)")
    if let data = deepLinkData {
        print("Link data: \(data)")
        // Navigate using deep link path
        if let path = data.deepLinkPath {
            navigateToPath(path)
        }
    }
}
```

> **Server-side resolution:** Pass every URL the app receives to `handleDeepLink`. An `http(s)` URL on the `baseURL` host or on one of your workspace's link hosts is resolved via the server to provide enriched data including `deepLinkPath`, `appScheme`, and `linkId`; any other URL, custom schemes included, reaches `onDeepLink` as a local parse without a request. The SDK learns the link hosts from the server when `appToken` is set; until they are known, and without an `appToken`, every `http(s)` URL is resolved. If the server is unreachable, the SDK falls back to local URL parsing.

### 4. Track Events

```swift
// Track a simple event
try await LinkForty.shared.trackEvent(name: "button_clicked")

// Track event with properties
try await LinkForty.shared.trackEvent(
    name: "purchase",
    properties: [
        "product_id": "123",
        "amount": 29.99,
        "currency": "USD"
    ]
)

// Track revenue
try await LinkForty.shared.trackRevenue(
    amount: 29.99,
    currency: "USD",
    properties: ["product_id": "123"]
)
```

Every event is automatically stamped with the deep link that most recently opened the app (last-click attribution), so the dashboard can show what users do *after* clicking a link. Events with no preceding deep-link open are reported as organic. No extra code is required.

### 5. Track Screen Views

Reporting screen views lets the dashboard build a per-link screen-flow funnel — which screens users reach after opening a deep link. Each `screen_view` carries the same last-click attribution stamp as other events.

**SwiftUI** — add the `.linkfortyScreen(_:)` modifier to a screen:

```swift
ProductView()
    .linkfortyScreen("ProductDetail")
```

**UIKit** — call from `viewDidAppear`:

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Task { try? await LinkForty.shared.trackScreenView(name: "ProductDetail") }
}
```

> There is no navigation swizzling: you mark the screens you care about, which keeps screen names meaningful and predictable. The SDK records the previous screen automatically so transitions appear in the funnel.

### 6. Create Links Programmatically

```swift
let result = try await LinkForty.shared.createLink(
    options: CreateLinkOptions(
        deepLinkParameters: ["route": "VIDEO_VIEWER", "id": "vid123"],
        title: "Check this out!",
        utmParameters: UTMParameters(source: "app", campaign: "share")
    )
)

print("Share this link: \(result.url)")
// e.g., "https://go.yourdomain.com/tmpl/abc123"
```

> **Note:** Requires an `apiKey` in `LinkFortyConfig` (without one, `createLink` throws `LinkFortyError.missingApiKey`) and a server that provides the SDK link endpoint `POST /api/sdk/v1/links`, as the hosted service does. A self-hosted Core server does not have that endpoint, and its `POST /api/links`, which the SDK falls back to, requires an `originalUrl` the SDK does not send, so `createLink` does not work against Core. See [API Reference](API.md#createlinkoptions) for all options.

## Advanced Usage

### Self-Hosted LinkForty Core

If you're running your own LinkForty Core instance, point `baseURL` at it. Core does not use an `appToken`, and no `apiKey` is needed (`createLink` is not available against Core):

```swift
let config = LinkFortyConfig(
    baseURL: URL(string: "https://links.yourcompany.com")!,
    debug: false
)
try await LinkForty.shared.initialize(config: config)
```

### Custom Attribution Window

```swift
let config = LinkFortyConfig(
    baseURL: URL(string: "https://api.linkforty.com")!,
    appToken: "at_a1b2c3d4...",
    attributionWindowHours: 24 // 1 day instead of default 7 days
)
```

### Retrieve Install Data

```swift
if let installData = LinkForty.shared.getInstallData() {
    print("Short code: \(installData.shortCode)")
    print("UTM source: \(installData.utmParameters?.source ?? "none")")
}

if let installId = LinkForty.shared.getInstallId() {
    print("Install ID: \(installId)")
}
```

### Event Queue Management

An event that can't be sent because of a network error or a server error (5xx) is kept on the device and sent later; `trackEvent` returns normally in that case. Each request is tried up to 3 times (with 1 s and 2 s pauses) before the event is left queued. The queue holds up to 100 events and survives app restarts; it is sent after `initialize`, when the app returns to the foreground, after the next event that sends, or when you call `flushEvents()`. When the queue is full, a new event that can't be sent is dropped without an error. An event the server rejects (4xx) throws and is not queued.

```swift
// Check queued events count
let count = LinkForty.shared.queuedEventCount

// Manually flush event queue
await LinkForty.shared.flushEvents()

// Clear event queue
LinkForty.shared.clearEventQueue()
```

### Clear Data (for testing)

```swift
LinkForty.shared.clearData()

// Reset SDK to uninitialized state
LinkForty.shared.reset()
```

## Universal Links Setup

### 1. Serve the AASA File

Every host your links are served on must serve an Apple App Site Association file at:
`https://go.yourdomain.com/.well-known/apple-app-site-association`

You don't upload this file: the LinkForty server generates it. On the hosted service it is served once your Apple Team ID and bundle ID are set in your app configuration. A self-hosted Core server serves it when the `IOS_TEAM_ID` and `IOS_BUNDLE_ID` environment variables are set, and answers 404 otherwise.

The generated file looks like this:
```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAM_ID.com.yourcompany.yourapp",
      "paths": ["*"]
    }]
  }
}
```

### 2. Configure Xcode

1. Enable "Associated Domains" capability
2. Add `applinks:<host>` for each host your links are served on, e.g. `applinks:go.yourdomain.com`
3. Pass incoming links to `handleDeepLink` from every entry point your app uses (see [Handle Direct Deep Links](#3-handle-direct-deep-links-universal-links))

### 3. Test Universal Links

Use Apple's validation tool:
- https://search.developer.apple.com/appsearch-validation-tool

Or test manually:
1. Create a link in LinkForty
2. Open link in Safari on device
3. Long press the link
4. Verify "Open in YourApp" appears

## Privacy & Security

### Privacy-First Design

- **No IDFA**: Does not read the Identifier for Advertisers, does not show an App Tracking Transparency prompt, and does not use SKAdNetwork
- **Probabilistic install matching**: A deferred deep link is matched to a click from device signals and the network, not from a device ID
- **Install ID**: The server assigns an install ID on the first launch. The SDK stores it on the device (in `UserDefaults`) and sends it with every event, so events are tied to that install
- **User Control**: Provides `clearData()` to delete the data the SDK stores on the device
- **Privacy Manifest**: Includes `PrivacyInfo.xcprivacy` (declares no tracking)

### Data Sent

When the install is reported:

- Device timezone and language
- Screen resolution (in pixels)
- iOS version and app version
- A user-agent string made from the app name, app version and iOS version
- The `appToken`, and the SDK name and version
- A `deviceId`, only if your app passes one to `initialize(config:attributionWindowHours:deviceId:)`

When a link is resolved on the server: timezone, language, screen resolution and iOS version.

With each event: the event name and the properties your app passes, the install ID, a session ID (new on each launch and each deep link open), and the ID of the link that last opened the app and when it opened (if any).

As with any network request, the server also sees the device's IP address.

### HTTPS Required

The SDK enforces HTTPS for all API endpoints (except localhost for testing).

## Testing

### Unit Tests

```bash
swift test
```

Or in Xcode:
`Cmd+U` to run all tests

### End-to-End Tests

See [`E2E/README.md`](E2E/README.md) for the simulator tests that run the SDK against a real LinkForty server.

## Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [LinkForty Docs](https://docs.linkforty.com)
- [Testing Strategy](docs/TESTING_STRATEGY.md)


## Example Apps

- [Basic Example](Examples/BasicExample/) - Simple SwiftUI app demonstrating all SDK features


## Backend

This SDK requires a running LinkForty backend:
- **LinkForty Core** (open source): Self-host for free
- **The hosted LinkForty service** ([linkforty.com](https://linkforty.com)): managed, nothing to run

See: https://github.com/LinkForty/core

## Support

- **Documentation**: [docs.linkforty.com](https://docs.linkforty.com)
- **Issues**: [GitHub Issues](https://github.com/LinkForty/mobile-sdk-ios/issues)
- **Discussions**: [GitHub Discussions](https://github.com/LinkForty/mobile-sdk-ios/discussions)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

LinkForty iOS SDK is available under the MIT license. See [LICENSE](LICENSE) for more info.

## Other SDKs

| Platform | Package |
|----------|---------|
| React Native | [`@linkforty/mobile-sdk-react-native`](https://github.com/LinkForty/mobile-sdk-react-native) |
| Expo | [`@linkforty/mobile-sdk-expo`](https://github.com/LinkForty/mobile-sdk-expo) |
| Android (Kotlin) | [LinkFortySDK](https://github.com/LinkForty/mobile-sdk-android) |
| Flutter | [`linkforty_flutter`](https://github.com/LinkForty/mobile-sdk-flutter) |

## Related Projects

- [LinkForty Core](https://github.com/LinkForty/core) — open-source self-hosted deep linking engine
- [LinkForty](https://linkforty.com) — the hosted service, with a dashboard
