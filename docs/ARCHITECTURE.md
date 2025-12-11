# LinkForty iOS SDK - Architecture Design

## Overview

The LinkForty iOS SDK is a native Swift framework for deep linking, install attribution, and conversion tracking. It provides seamless integration with both LinkForty Core (open source) and LinkForty Cloud (SaaS) backends.

## Design Principles

1. **Privacy-First**: Compliant with Apple's App Tracking Transparency (ATT) framework
2. **No Persistent IDs**: Uses probabilistic fingerprinting without storing persistent device identifiers
3. **Swift-Native**: Pure Swift implementation with no Objective-C dependencies
4. **Minimal Dependencies**: Core functionality with no third-party dependencies
5. **Thread-Safe**: All public APIs are thread-safe and async-aware
6. **Lightweight**: Small binary footprint, minimal memory usage
7. **Backward Compatible**: Support iOS 13.0+

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      App Layer                               │
│  (SwiftUI/UIKit App integrating LinkForty SDK)              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│              LinkForty Public API                            │
│                                                              │
│  • LinkForty.shared.initialize()                            │
│  • onDeferredDeepLink(callback)                             │
│  • onDeepLink(callback)                                     │
│  • trackEvent(name, properties)                             │
│  • getInstallData()                                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴─────────────────────────────────────┐
│                 Core Components                            │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Configuration Manager                          │       │
│  │  • SDK configuration                            │       │
│  │  • API endpoints                                │       │
│  │  • Attribution window settings                  │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Deep Link Handler                              │       │
│  │  • Universal Links processing                   │       │
│  │  • Custom URL scheme handling                   │       │
│  │  • URL parameter extraction                     │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Fingerprint Collector                          │       │
│  │  • Device characteristics (non-invasive)        │       │
│  │  • Timezone, language, screen resolution        │       │
│  │  • User-Agent generation                        │       │
│  │  • No IDFA or persistent IDs                    │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Attribution Manager                            │       │
│  │  • Install attribution via fingerprinting       │       │
│  │  • Deferred deep link resolution                │       │
│  │  • Confidence score calculation                 │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Event Tracker                                  │       │
│  │  • Custom event tracking                        │       │
│  │  • Revenue/conversion tracking                  │       │
│  │  • Event queuing & retry logic                  │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Network Manager                                │       │
│  │  • URLSession-based HTTP client                 │       │
│  │  • Bearer token authentication                  │       │
│  │  • Retry logic with exponential backoff         │       │
│  │  • Request/response logging (debug mode)        │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Storage Manager                                │       │
│  │  • UserDefaults for data persistence            │       │
│  │  • Keychain for sensitive data (optional)       │       │
│  │  • Install ID caching                           │       │
│  │  • Deep link data caching                       │       │
│  └─────────────────────────────────────────────────┘       │
│                                                            │
└──────────────────────┬─────────────────────────────────────┘
                       │
┌──────────────────────┴─────────────────────────────────────┐
│                 System Frameworks                          │
│                                                            │
│  • Foundation (URLSession, UserDefaults, Locale, etc.)     │
│  • UIKit (UIDevice, UIScreen)                              │
│  • SystemConfiguration (Network reachability - optional)   │
└────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### 1. LinkForty Singleton

**Responsibilities:**
- Exposes all public SDK APIs
- Manages SDK lifecycle (initialization, state)
- Coordinates between internal components
- Ensures thread-safety via serial dispatch queue

**Key Methods:**
```swift
public class LinkForty {
    public static let shared: LinkForty

    public func initialize(config: LinkFortyConfig) async throws
    public func onDeferredDeepLink(_ callback: @escaping DeferredDeepLinkCallback)
    public func onDeepLink(_ callback: @escaping DeepLinkCallback)
    public func trackEvent(name: String, properties: [String: Any]?) async throws
    public func getInstallData() -> DeepLinkData?
    public func getInstallId() -> String?
    public func clearData() async
}
```

### 2. Configuration Manager

**Responsibilities:**
- Validates and stores SDK configuration
- Manages API endpoints
- Provides configuration to other components

**Configuration:**
```swift
public struct LinkFortyConfig {
    let baseURL: URL
    let apiKey: String?
    let debug: Bool
    let attributionWindowHours: Int
}
```

### 3. Deep Link Handler

**Responsibilities:**
- Processes incoming Universal Links
- Handles custom URL schemes
- Extracts query parameters and deep link data
- Manages callback registration and invocation

**Integration:**
- Receives URLs from `SceneDelegate` or `AppDelegate`
- Parses URL structure and parameters
- Invokes registered callbacks with parsed data

### 4. Fingerprint Collector

**Responsibilities:**
- Collects non-invasive device characteristics
- Generates device fingerprint for attribution matching
- Complies with Apple privacy requirements

**Collected Data:**
- User-Agent string (iOS version, device model)
- Timezone identifier (e.g., "America/New_York")
- Preferred languages (e.g., ["en-US"])
- Screen resolution (width, height)
- Platform info (iOS, version)
- App version

**Not Collected:**
- IDFA (Identifier for Advertisers)
- IDFV (Identifier for Vendor) - optional, user consent required
- MAC addresses
- Persistent device identifiers

### 5. Attribution Manager

**Responsibilities:**
- Reports install events to backend
- Receives attribution results
- Caches deferred deep link data
- Calculates local confidence scores

**Flow:**
1. On first launch, collect fingerprint
2. Send `POST /api/sdk/v1/install` with fingerprint
3. Backend matches against recent clicks (within attribution window)
4. Returns deep link data + confidence score
5. Cache attribution data locally
6. Invoke deferred deep link callback

### 6. Event Tracker

**Responsibilities:**
- Tracks custom in-app events
- Queues events when offline
- Retries failed events
- Associates events with install ID

**Features:**
- Offline queueing (max 100 events)
- Automatic retry with exponential backoff
- Event validation
- Revenue tracking support

### 7. Network Manager

**Responsibilities:**
- Centralized HTTP client
- Authentication header injection
- Error handling and retry logic
- Request/response logging (debug mode)

**Features:**
- URLSession-based
- Bearer token authentication
- Timeout configuration (30s default)
- Retry logic (3 attempts max)
- Exponential backoff (1s, 2s, 4s)

### 8. Storage Manager

**Responsibilities:**
- Persist SDK data across app launches
- Manage install ID
- Cache deep link data
- Store first launch flag

**Storage Keys:**
```
com.linkforty.sdk.installId
com.linkforty.sdk.installData
com.linkforty.sdk.firstLaunch
```

**Data Store:**
- UserDefaults for non-sensitive data
- Optional: Keychain for sensitive data (API keys if stored)

## Data Models

### DeepLinkData
```swift
public struct DeepLinkData: Codable {
    let shortCode: String
    let iosURL: String?
    let androidURL: String?
    let webURL: String?
    let utmParameters: UTMParameters?
    let customParameters: [String: String]?
    let clickedAt: Date?
    let linkId: String?
}
```

### UTMParameters
```swift
public struct UTMParameters: Codable {
    let source: String?
    let medium: String?
    let campaign: String?
    let term: String?
    let content: String?
}
```

### InstallResponse
```swift
struct InstallResponse: Codable {
    let installId: String
    let attributed: Bool
    let confidenceScore: Double
    let matchedFactors: [String]
    let deepLinkData: DeepLinkData?
}
```

### EventRequest
```swift
struct EventRequest: Codable {
    let installId: String
    let eventName: String
    let eventData: [String: Any]
    let timestamp: String
}
```

## Thread Safety

### Concurrency Model
- **Main Actor**: UI callbacks executed on main thread
- **Background Queue**: Network requests on background threads
- **Serial Queue**: Internal state management via serial DispatchQueue

### Async/Await
- All public async methods use Swift's `async/await`
- Internal components use `DispatchQueue` for backward compatibility
- Callbacks bridged to async context where needed

## Privacy Compliance

### App Tracking Transparency (ATT)
- SDK does **not** require ATT permission
- No IDFA collection by default
- Optional IDFA collection with explicit user consent

### Privacy Manifest
- Includes `PrivacyInfo.xcprivacy` manifest
- Declares collected data types:
  - Device characteristics (timezone, language, screen)
  - App version
  - Network usage
- Declares API usage:
  - UserDefaults (data persistence)
  - Network APIs (attribution, event tracking)

### Data Minimization
- Only collects data necessary for attribution
- No persistent device identifiers stored
- Attribution window limits data retention
- Provides `clearData()` for user control

## Integration with LinkForty Backend

### API Endpoints

#### POST /api/sdk/v1/install
**Request:**
```json
{
  "userAgent": "MyApp/1.0 iOS/15.0",
  "timezone": "America/New_York",
  "language": "en-US",
  "screenWidth": 1170,
  "screenHeight": 2532,
  "platform": "iOS",
  "platformVersion": "15.0",
  "appVersion": "1.0.0",
  "attributionWindowHours": 168
}
```

**Response:**
```json
{
  "installId": "uuid-here",
  "attributed": true,
  "confidenceScore": 85,
  "matchedFactors": ["userAgent", "timezone", "screenResolution"],
  "deepLinkData": {
    "shortCode": "abc123",
    "iosURL": "https://example.com/product/123",
    "utmParameters": { "source": "facebook", "campaign": "summer-sale" },
    "customParameters": { "productId": "123" }
  }
}
```

#### POST /api/sdk/v1/event
**Request:**
```json
{
  "installId": "uuid-here",
  "eventName": "purchase",
  "eventData": {
    "productId": "123",
    "revenue": 29.99,
    "currency": "USD"
  },
  "timestamp": "2024-01-15T12:00:00Z"
}
```

**Response:**
```json
{
  "success": true
}
```

### Authentication
- **Self-Hosted (Core)**: No authentication required
- **Cloud**: Bearer token via `Authorization` header
  ```
  Authorization: Bearer your-api-key-here
  ```

## Universal Links Setup

### Associated Domains Configuration
1. Enable "Associated Domains" capability in Xcode
2. Add domain: `applinks:go.yourdomain.com`

### AASA File (Apple App Site Association)
Backend must serve at: `https://go.yourdomain.com/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAM_ID.com.yourapp.bundle",
      "paths": ["*"]
    }]
  }
}
```

### App Delegate Integration
```swift
func application(_ application: UIApplication,
                continue userActivity: NSUserActivity,
                restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return false
    }

    LinkForty.shared.handleUniversalLink(url)
    return true
}
```

## Error Handling

### Error Types
```swift
public enum LinkFortyError: Error {
    case notInitialized
    case invalidConfiguration
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case alreadyInitialized
}
```

### Error Propagation
- Async methods throw errors for critical failures
- Non-critical errors logged (debug mode)
- Callbacks receive `nil` on attribution failure
- Event tracking fails silently with retry

## Performance Considerations

### Initialization
- Lightweight: < 50ms on modern devices
- Background thread for network calls
- Non-blocking UI

### Memory Footprint
- Target: < 2MB memory usage
- Event queue limit: 100 events
- Cached data: < 50KB

### Network Efficiency
- Batch event tracking (future enhancement)
- Gzip compression support
- Request deduplication
- Exponential backoff for retries

## Testing Strategy

### Unit Tests
- Mock network responses
- Test fingerprint collection
- Validate data parsing
- Test storage operations

### Integration Tests
- Test against local LinkForty Core instance
- Verify Universal Links handling
- Test attribution flow end-to-end

### Privacy Tests
- Verify no IDFA collection without consent
- Validate data minimization
- Test data clearing functionality

## Future Enhancements

### Phase 2
- Batch event tracking
- Offline event persistence to disk
- Advanced retry strategies
- Network reachability monitoring

### Phase 3
- SwiftUI-specific APIs
- Combine publishers for callbacks
- SPM binary framework distribution
- App Clips support

### Phase 4
- Advanced attribution models
- Cross-device tracking (privacy-compliant)
- A/B testing support
- Real-time analytics dashboard
