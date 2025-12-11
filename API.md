# LinkForty iOS SDK - API Reference

Complete API reference for the LinkForty iOS SDK.

## Table of Contents

- [LinkForty](#linkforty) - Main SDK class
- [LinkFortyConfig](#linkfortyconfig) - Configuration
- [DeepLinkData](#deeplinkdata) - Deep link data model
- [InstallResponse](#installresponse) - Attribution response
- [LinkFortyError](#linkfortyerror) - Error types
- [Type Aliases](#type-aliases) - Callback types

---

## LinkForty

Main singleton class providing the SDK interface.

### Singleton Access

```swift
LinkForty.shared
```

### Methods

#### initialize(config:attributionWindowHours:deviceId:)

Initializes the SDK with configuration and reports the install.

```swift
func initialize(
    config: LinkFortyConfig,
    attributionWindowHours: Int = 168,
    deviceId: String? = nil
) async throws -> InstallResponse
```

**Parameters:**
- `config`: SDK configuration (required)
- `attributionWindowHours`: Attribution window in hours (default: 168 = 7 days)
- `deviceId`: Optional device identifier for attribution

**Returns:** `InstallResponse` with attribution data

**Throws:** `LinkFortyError` if initialization fails

**Example:**
```swift
let config = LinkFortyConfig(
    baseURL: URL(string: "https://go.yourdomain.com")!,
    apiKey: "your-api-key"
)
let response = try await LinkForty.shared.initialize(config: config)
print("Install ID: \(response.installId)")
print("Attributed: \(response.attributed)")
```

---

#### handleDeepLink(url:)

Handles a deep link URL (Universal Link or custom scheme).

```swift
func handleDeepLink(url: URL)
```

**Parameters:**
- `url`: The deep link URL to handle

**Example:**
```swift
// In SwiftUI
.onOpenURL { url in
    LinkForty.shared.handleDeepLink(url: url)
}

// In AppDelegate
func application(_ application: UIApplication,
                continue userActivity: NSUserActivity,
                restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if let url = userActivity.webpageURL {
        LinkForty.shared.handleDeepLink(url: url)
    }
    return true
}
```

---

#### onDeferredDeepLink(_:)

Registers a callback for deferred deep links (install attribution).

```swift
func onDeferredDeepLink(_ callback: @escaping DeferredDeepLinkCallback)
```

**Parameters:**
- `callback`: Closure invoked with deep link data (or nil for organic installs)

**Callback Type:**
```swift
typealias DeferredDeepLinkCallback = (DeepLinkData?) -> Void
```

**Example:**
```swift
LinkForty.shared.onDeferredDeepLink { deepLinkData in
    if let data = deepLinkData {
        print("Attributed install: \(data.shortCode ?? "unknown")")
        // Navigate to content
    } else {
        print("Organic install")
    }
}
```

---

#### onDeepLink(_:)

Registers a callback for direct deep links (when app opens from a link).

```swift
func onDeepLink(_ callback: @escaping DeepLinkCallback)
```

**Parameters:**
- `callback`: Closure invoked with URL and parsed deep link data

**Callback Type:**
```swift
typealias DeepLinkCallback = (URL, DeepLinkData?) -> Void
```

**Example:**
```swift
LinkForty.shared.onDeepLink { url, deepLinkData in
    print("Opened from: \(url)")
    if let data = deepLinkData {
        // Navigate based on deep link data
    }
}
```

---

#### trackEvent(name:properties:)

Tracks a custom event.

```swift
func trackEvent(
    name: String,
    properties: [String: Any]? = nil
) async throws
```

**Parameters:**
- `name`: Event name (e.g., "purchase", "signup")
- `properties`: Optional event properties (must be JSON-serializable)

**Throws:** `LinkFortyError` if tracking fails

**Example:**
```swift
// Simple event
try await LinkForty.shared.trackEvent(name: "button_clicked")

// Event with properties
try await LinkForty.shared.trackEvent(
    name: "purchase",
    properties: [
        "product_id": "123",
        "amount": 29.99,
        "category": "electronics"
    ]
)
```

---

#### trackRevenue(amount:currency:properties:)

Tracks a revenue event.

```swift
func trackRevenue(
    amount: Decimal,
    currency: String,
    properties: [String: Any]? = nil
) async throws
```

**Parameters:**
- `amount`: Revenue amount (must be non-negative)
- `currency`: Currency code (e.g., "USD", "EUR")
- `properties`: Optional additional properties

**Throws:** `LinkFortyError` if tracking fails

**Example:**
```swift
try await LinkForty.shared.trackRevenue(
    amount: 29.99,
    currency: "USD",
    properties: [
        "product_id": "123",
        "payment_method": "credit_card"
    ]
)
```

---

#### flushEvents()

Flushes the event queue, attempting to send all queued events.

```swift
func flushEvents() async
```

**Example:**
```swift
await LinkForty.shared.flushEvents()
```

---

#### clearEventQueue()

Clears the event queue without sending events.

```swift
func clearEventQueue()
```

**Example:**
```swift
LinkForty.shared.clearEventQueue()
```

---

### Properties

#### queuedEventCount

Returns the number of events currently queued.

```swift
var queuedEventCount: Int { get }
```

**Example:**
```swift
let count = LinkForty.shared.queuedEventCount
print("Queued events: \(count)")
```

---

### Attribution Data Methods

#### getInstallId()

Returns the install ID if available.

```swift
func getInstallId() -> String?
```

**Returns:** Install ID or nil if not initialized

**Example:**
```swift
if let installId = LinkForty.shared.getInstallId() {
    print("Install ID: \(installId)")
}
```

---

#### getInstallData()

Returns the install attribution data if available.

```swift
func getInstallData() -> DeepLinkData?
```

**Returns:** Deep link data or nil if organic install

**Example:**
```swift
if let data = LinkForty.shared.getInstallData() {
    print("Short code: \(data.shortCode ?? "unknown")")
    print("UTM source: \(data.utmParameters?.source ?? "none")")
}
```

---

#### isFirstLaunch()

Returns whether this is the first launch.

```swift
func isFirstLaunch() -> Bool
```

**Returns:** true if first launch, false otherwise

**Example:**
```swift
if LinkForty.shared.isFirstLaunch() {
    print("First launch - show onboarding")
}
```

---

### Data Management Methods

#### clearData()

Clears all stored SDK data.

```swift
func clearData()
```

**Example:**
```swift
LinkForty.shared.clearData()
```

---

#### reset()

Resets the SDK to uninitialized state.

**Note:** This does NOT clear stored data. Call `clearData()` first if needed.

```swift
func reset()
```

**Example:**
```swift
LinkForty.shared.clearData()
LinkForty.shared.reset()
```

---

## LinkFortyConfig

Configuration for the LinkForty SDK.

### Initializer

```swift
init(
    baseURL: URL,
    apiKey: String? = nil,
    debug: Bool = false,
    attributionWindowHours: Int = 168
)
```

**Parameters:**
- `baseURL`: Backend URL (must be HTTPS except localhost)
- `apiKey`: API key (optional for self-hosted)
- `debug`: Enable debug logging (default: false)
- `attributionWindowHours`: Attribution window in hours (default: 168 = 7 days, max: 2160 = 90 days)

**Example:**
```swift
let config = LinkFortyConfig(
    baseURL: URL(string: "https://go.yourdomain.com")!,
    apiKey: "your-api-key",
    debug: true,
    attributionWindowHours: 24
)
```

### Properties

- `baseURL: URL` - Backend URL
- `apiKey: String?` - API key (optional)
- `debug: Bool` - Debug mode flag
- `attributionWindowHours: Int` - Attribution window

### Methods

#### validate()

Validates the configuration.

```swift
func validate() throws
```

**Throws:** `LinkFortyError.invalidConfiguration` if validation fails

---

## DeepLinkData

Deep link data model containing parsed link information.

### Properties

```swift
public let shortCode: String?           // LinkForty short code
public let iosURL: String?             // iOS deep link URL
public let androidURL: String?         // Android deep link URL
public let webURL: String?             // Fallback web URL
public let utmParameters: UTMParameters?  // UTM tracking parameters
public let customParameters: [String: String]  // Custom parameters
public let createdAt: Date?            // Link creation date
public let expiresAt: Date?            // Link expiration date
```

### Example

```swift
if let data = deepLinkData {
    print("Short code: \(data.shortCode ?? "none")")

    if let utm = data.utmParameters {
        print("Source: \(utm.source ?? "unknown")")
        print("Campaign: \(utm.campaign ?? "unknown")")
    }

    if let productId = data.customParameters["product_id"] {
        navigateToProduct(id: productId)
    }
}
```

---

## InstallResponse

Response from install attribution API.

### Properties

```swift
public let installId: String           // Unique install ID
public let attributed: Bool            // Whether install was attributed
public let confidenceScore: Double     // Confidence score (0-100)
public let matchedFactors: [String]    // Matched fingerprint factors
public let deepLinkData: DeepLinkData? // Deep link data if attributed
```

### Example

```swift
let response = try await LinkForty.shared.initialize(config: config)

print("Install ID: \(response.installId)")
print("Attributed: \(response.attributed)")

if response.attributed {
    print("Confidence: \(response.confidenceScore)%")
    print("Matched factors: \(response.matchedFactors)")

    if let data = response.deepLinkData {
        print("Short code: \(data.shortCode ?? "unknown")")
    }
}
```

---

## LinkFortyError

Error types thrown by the SDK.

### Cases

```swift
case notInitialized
    // SDK not initialized - call initialize() first

case alreadyInitialized
    // SDK already initialized

case invalidConfiguration(String)
    // Invalid configuration

case networkError(Error)
    // Network request failed

case invalidResponse(statusCode: Int?, message: String)
    // Invalid or unexpected server response

case decodingError(Error)
    // Failed to decode response

case encodingError(Error)
    // Failed to encode request

case invalidEventData(String)
    // Invalid event data
```

### Example

```swift
do {
    try await LinkForty.shared.trackEvent(name: "test")
} catch let error as LinkFortyError {
    switch error {
    case .notInitialized:
        print("SDK not initialized")
    case .networkError(let underlyingError):
        print("Network error: \(underlyingError)")
    case .invalidEventData(let message):
        print("Invalid event: \(message)")
    default:
        print("Error: \(error)")
    }
}
```

---

## Type Aliases

### DeferredDeepLinkCallback

Callback for deferred deep links (install attribution).

```swift
typealias DeferredDeepLinkCallback = (DeepLinkData?) -> Void
```

**Parameter:** Deep link data if attributed, nil for organic installs

---

### DeepLinkCallback

Callback for direct deep links (when app opens from a link).

```swift
typealias DeepLinkCallback = (URL, DeepLinkData?) -> Void
```

**Parameters:**
- `URL`: The URL that opened the app
- `DeepLinkData?`: Parsed deep link data, nil if parsing failed

---

## Thread Safety

All SDK methods are thread-safe and can be called from any thread. Callbacks are executed on the main thread.

## Async/Await Support

The SDK uses modern Swift concurrency (async/await) for asynchronous operations:

```swift
// All async methods can be called with await
try await LinkForty.shared.initialize(config: config)
try await LinkForty.shared.trackEvent(name: "test")
await LinkForty.shared.flushEvents()
```

## Offline Support

Events are automatically queued when offline and sent when connectivity is restored. The queue has a maximum size of 100 events.

---

For more information, see the [full documentation](README.md) or [LinkForty Docs](https://docs.linkforty.com).
