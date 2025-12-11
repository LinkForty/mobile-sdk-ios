# LinkForty iOS SDK

**Native iOS SDK for deep linking, mobile attribution, and conversion tracking.**

[![Swift Version](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://www.apple.com/ios)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)

## Features

- **Deferred Deep Linking**: Match app installs to link clicks using privacy-compliant fingerprinting
- **Universal Links**: Full support for iOS Universal Links (HTTPS deep links)
- **Custom URL Schemes**: Handle custom app URL schemes
- **Event Tracking**: Track in-app events and conversions
- **Offline Support**: Queue events when offline with automatic retry
- **Privacy-First**: No IDFA collection, complies with Apple's privacy requirements
- **Zero Dependencies**: Lightweight, no third-party dependencies
- **Swift-Native**: 100% Swift, modern async/await APIs

## Requirements

- iOS 13.0+
- Xcode 14.0+
- Swift 5.9+

## Installation

### Swift Package Manager (Recommended)

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/LinkForty/mobile-sdk-ios.git", from: "1.0.0")
]
```

Or in Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/LinkForty/mobile-sdk-ios.git`
3. Select version and add to your target

### CocoaPods

```ruby
pod 'LinkFortySDK', '~> 1.0'
```

### Carthage

```
github "LinkForty/mobile-sdk-ios" ~> 1.0
```

## Quick Start

### 1. Initialize the SDK

In your `AppDelegate.swift` or `@main` App struct:

```swift
import LinkFortySDK

// In AppDelegate
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Task {
        do {
            let config = LinkFortyConfig(
                baseURL: URL(string: "https://go.yourdomain.com")!,
                apiKey: "your-api-key", // Optional for self-hosted
                debug: true,
                attributionWindowHours: 168 // 7 days
            )
            try await LinkForty.shared.initialize(config: config)
        } catch {
            print("LinkForty initialization failed: \(error)")
        }
    }
    return true
}
```

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

### 3. Handle Direct Deep Links (Universal Links)

First, enable Associated Domains in your Xcode project:
1. Select your target > Signing & Capabilities
2. Add "Associated Domains"
3. Add domain: `applinks:go.yourdomain.com`

Then handle Universal Links:

```swift
// In AppDelegate or SceneDelegate
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

// Or in SwiftUI
.onOpenURL { url in
    LinkForty.shared.handleDeepLink(url: url)
}

// Register callback
LinkForty.shared.onDeepLink { url, deepLinkData in
    print("Deep link opened: \(url)")
    if let data = deepLinkData {
        print("Link data: \(data)")
        // Navigate to content
    }
}
```

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

## Advanced Usage

### Self-Hosted LinkForty Core

If you're running your own LinkForty Core instance:

```swift
let config = LinkFortyConfig(
    baseURL: URL(string: "https://links.yourcompany.com")!,
    apiKey: nil, // No API key needed for self-hosted
    debug: false
)
try await LinkForty.shared.initialize(config: config)
```

### Custom Attribution Window

```swift
let config = LinkFortyConfig(
    baseURL: URL(string: "https://go.yourdomain.com")!,
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

### 1. Create AASA File

Your backend must serve an Apple App Site Association file at:
`https://go.yourdomain.com/.well-known/apple-app-site-association`

Example:
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
2. Add domain: `applinks:go.yourdomain.com`
3. Handle Universal Links in AppDelegate (see Quick Start)

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

- **No IDFA**: Does not collect Identifier for Advertisers
- **No Persistent IDs**: Uses probabilistic fingerprinting only
- **Data Minimization**: Collects only necessary attribution data
- **User Control**: Provides `clearData()` for user data deletion
- **Privacy Manifest**: Includes `PrivacyInfo.xcprivacy` file

### Data Collected (for attribution only)

- Device timezone
- Device language
- Screen resolution
- iOS version
- App version
- User-Agent string

### HTTPS Required

The SDK enforces HTTPS for all API endpoints (except localhost for testing).

## Testing

### Unit Tests

```bash
swift test
```

Or in Xcode:
`Cmd+U` to run all tests

### Integration Tests

See `Tests/LinkFortySDKIntegrationTests/README.md` for setup instructions.

## Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [LinkForty Docs](https://docs.linkforty.com)
- [Testing Strategy](docs/TESTING_STRATEGY.md)


## Example Apps

- [Basic Example](Examples/BasicExample/) - Simple SwiftUI app demonstrating all SDK features


## Requirements

### Backend

This SDK requires a running LinkForty backend:
- **LinkForty Core** (open source): Self-host for free
- **LinkForty Cloud** (SaaS): Managed service with advanced features

See: https://github.com/linkforty/core

## Support

- **Documentation**: https://docs.linkforty.com
- **Issues**: https://github.com/LinkForty/mobile-sdk-ios/issues
- **Discussions**: https://github.com/LinkForty/mobile-sdk-ios/discussions

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

LinkForty iOS SDK is available under the MIT license. See [LICENSE](LICENSE) for more info.

## Related Projects

- [LinkForty Core](https://github.com/linkforty/core) - Open source deep linking backend
- [LinkForty React Native SDK](https://github.com/linkforty/mobile-sdk-react-native) - React Native integration
- [LinkForty Android SDK](https://github.com/linkforty/mobile-sdk-android) - Android SDK *(coming soon)*

---

Made with ❤️ by the LinkForty team
