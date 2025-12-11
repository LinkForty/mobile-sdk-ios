# LinkForty iOS SDK - Testing Strategy

## Overview

This document outlines the comprehensive testing strategy for the LinkForty iOS SDK. Our goal is to achieve 80%+ code coverage with a robust suite of unit, integration, and end-to-end tests while ensuring privacy compliance and performance standards.

## Testing Pyramid

```
                    ┌──────────────┐
                    │  E2E Tests   │  ~10 tests
                    │   (Manual)   │
                    └──────────────┘
                  ┌────────────────────┐
                  │ Integration Tests  │  ~50 tests
                  │  (Backend + SDK)   │
                  └────────────────────┘
              ┌──────────────────────────────┐
              │      Unit Tests              │  ~200 tests
              │  (Mocked Dependencies)       │
              └──────────────────────────────┘
```

**Testing Ratio**: 80% unit tests, 15% integration tests, 5% E2E tests

## Test Targets

| Test Type | Target Count | Target Coverage | Priority |
|-----------|--------------|-----------------|----------|
| Unit Tests | 200+ | 80%+ | High |
| Integration Tests | 50+ | API integration | High |
| UI Tests | 10+ | Example app flows | Medium |
| Performance Tests | 20+ | Benchmarks met | High |
| Privacy Tests | 15+ | 100% compliance | Critical |

## Testing Tools & Frameworks

### Primary Testing Framework
- **XCTest**: Apple's native testing framework
- **Swift Testing**: For modern async/await tests (iOS 16+)

### Mocking & Stubbing
- **Protocol-based mocking**: Manual mocks via protocols
- **URLProtocol**: For mocking network requests
- **UserDefaults mocking**: In-memory test defaults

### Test Utilities
- **XCTestExpectation**: For async operation testing
- **Instruments**: Performance profiling
- **Network Link Conditioner**: Network condition simulation
- **Console.app**: System log validation

### CI/CD
- **GitHub Actions**: Automated test execution
- **Xcode Cloud**: Alternative CI (optional)
- **Codecov**: Code coverage reporting

## Unit Testing Strategy

### Target: 200+ Tests, 80%+ Coverage

### 1. Model Tests (~30 tests)

**LinkFortyConfig**
- ✅ Valid configuration initialization
- ✅ Invalid URL handling
- ✅ Attribution window validation (1-2160 hours)
- ✅ Debug flag defaults

**DeepLinkData**
- ✅ Codable encoding/decoding
- ✅ Optional field handling
- ✅ UTM parameter parsing
- ✅ Custom parameter parsing
- ✅ Date parsing (ISO 8601)

**InstallResponse**
- ✅ Codable encoding/decoding
- ✅ Attribution flag handling
- ✅ Confidence score validation (0-100)
- ✅ Deep link data optional handling

**EventRequest**
- ✅ Codable encoding/decoding
- ✅ Timestamp formatting
- ✅ Properties serialization (Any -> JSON)

**LinkFortyError**
- ✅ Error description strings
- ✅ LocalizedError conformance
- ✅ Error codes

### 2. Storage Manager Tests (~25 tests)

**UserDefaults Operations**
- ✅ Save and retrieve install ID
- ✅ Save and retrieve install data
- ✅ First launch flag detection
- ✅ Clear all data
- ✅ Thread safety (concurrent reads/writes)
- ✅ Data persistence across app launches (simulated)
- ✅ Nil handling for missing data
- ✅ Invalid data handling (corrupted JSON)

**Test Example**:
```swift
func testSaveAndRetrieveInstallId() {
    let storage = StorageManager(userDefaults: mockUserDefaults)
    let testId = "test-install-id-123"

    storage.saveInstallId(testId)
    let retrieved = storage.getInstallId()

    XCTAssertEqual(retrieved, testId)
}

func testFirstLaunchFlag() {
    let storage = StorageManager(userDefaults: mockUserDefaults)

    XCTAssertTrue(storage.isFirstLaunch()) // Default true
    storage.saveFirstLaunchFlag(false)
    XCTAssertFalse(storage.isFirstLaunch())
}
```

### 3. Network Manager Tests (~40 tests)

**Request Building**
- ✅ URL construction with base URL + endpoint
- ✅ HTTP method setting (GET, POST)
- ✅ Headers injection (Content-Type, Authorization)
- ✅ Body encoding (JSON)
- ✅ Query parameters encoding

**Authentication**
- ✅ Bearer token injection when API key provided
- ✅ No Authorization header when no API key
- ✅ Header override handling

**Response Handling**
- ✅ Success response parsing (200-299)
- ✅ Error response handling (400, 401, 404, 500)
- ✅ Invalid JSON response
- ✅ Empty response body
- ✅ Network timeout
- ✅ No internet connection

**Retry Logic**
- ✅ Retry on network failure (up to 3 times)
- ✅ Exponential backoff (1s, 2s, 4s)
- ✅ No retry on 4xx client errors
- ✅ Retry on 5xx server errors
- ✅ Retry count exhaustion

**Mock URLSession**:
```swift
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError { throw error }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}
```

### 4. Fingerprint Collector Tests (~20 tests)

**Data Collection**
- ✅ User-Agent string generation
- ✅ Timezone identifier (e.g., "America/New_York")
- ✅ Language codes (e.g., ["en-US", "es-MX"])
- ✅ Screen resolution (width, height)
- ✅ Platform detection ("iOS")
- ✅ Platform version (iOS version)
- ✅ App version from Bundle
- ✅ Device model (optional)

**Privacy Compliance**
- ✅ No IDFA collection by default
- ✅ No persistent identifiers
- ✅ No MAC address collection
- ✅ No location data collection

**Edge Cases**
- ✅ Missing Bundle info (fallback values)
- ✅ Simulator vs. physical device
- ✅ iPad vs. iPhone detection

**Test Example**:
```swift
func testFingerprintCollectionContainsRequiredFields() {
    let collector = FingerprintCollector()
    let fingerprint = collector.collectFingerprint()

    XCTAssertNotNil(fingerprint.userAgent)
    XCTAssertNotNil(fingerprint.timezone)
    XCTAssertNotNil(fingerprint.language)
    XCTAssertGreaterThan(fingerprint.screenWidth, 0)
    XCTAssertGreaterThan(fingerprint.screenHeight, 0)
    XCTAssertEqual(fingerprint.platform, "iOS")
}

func testNoIDFACollectedByDefault() {
    let collector = FingerprintCollector()
    let fingerprint = collector.collectFingerprint()

    XCTAssertNil(fingerprint.deviceId)
}
```

### 5. Attribution Manager Tests (~30 tests)

**Install Reporting**
- ✅ First launch install report
- ✅ Fingerprint data sent correctly
- ✅ Attribution window sent correctly
- ✅ Install ID cached after response
- ✅ Deep link data cached when attributed
- ✅ Nil deep link data when not attributed

**Attribution Response Handling**
- ✅ Parse attributed response (attributed: true)
- ✅ Parse organic response (attributed: false)
- ✅ Handle confidence score
- ✅ Handle matched factors array
- ✅ Handle missing deep link data

**Error Handling**
- ✅ Network error during install report
- ✅ Invalid response format
- ✅ 401 unauthorized (Cloud)
- ✅ 500 server error
- ✅ Timeout

**Caching**
- ✅ Install ID persisted to storage
- ✅ Deep link data persisted to storage
- ✅ Data retrieved from cache on subsequent calls

**Test Example**:
```swift
func testReportInstallAttributedResponse() async throws {
    let mockNetwork = MockNetworkManager()
    let mockStorage = MockStorageManager()
    let manager = AttributionManager(network: mockNetwork, storage: mockStorage)

    mockNetwork.mockResponse = InstallResponse(
        installId: "test-id",
        attributed: true,
        confidenceScore: 85,
        matchedFactors: ["userAgent", "timezone"],
        deepLinkData: DeepLinkData(shortCode: "abc123")
    )

    let fingerprint = DeviceFingerprint(/* ... */)
    let response = try await manager.reportInstall(fingerprint: fingerprint, attributionWindowHours: 168)

    XCTAssertEqual(response.installId, "test-id")
    XCTAssertTrue(response.attributed)
    XCTAssertEqual(mockStorage.savedInstallId, "test-id")
    XCTAssertNotNil(mockStorage.savedInstallData)
}
```

### 6. Deep Link Handler Tests (~30 tests)

**URL Parsing**
- ✅ Parse shortCode from URL path
- ✅ Parse UTM parameters (source, medium, campaign, term, content)
- ✅ Parse custom query parameters
- ✅ Handle URL encoding/decoding
- ✅ Handle special characters
- ✅ Handle empty query parameters

**Callback Management**
- ✅ Register deferred deep link callback
- ✅ Register direct deep link callback
- ✅ Invoke callbacks on main thread
- ✅ Handle multiple callback registrations
- ✅ Handle nil callbacks

**Edge Cases**
- ✅ Malformed URLs
- ✅ Missing shortCode
- ✅ URLs with fragments (#)
- ✅ URLs with ports
- ✅ International characters

**Test Example**:
```swift
func testParseUTMParameters() {
    let handler = DeepLinkHandler()
    let url = URL(string: "https://go.example.com/abc123?utm_source=facebook&utm_campaign=summer")!

    let data = handler.parseDeepLink(from: url)

    XCTAssertEqual(data.shortCode, "abc123")
    XCTAssertEqual(data.utmParameters?.source, "facebook")
    XCTAssertEqual(data.utmParameters?.campaign, "summer")
}

func testCallbackInvokedOnMainThread() {
    let handler = DeepLinkHandler()
    let expectation = XCTestExpectation(description: "Callback on main thread")

    handler.onDeepLink { url, data in
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    handler.handleDeepLink(url: URL(string: "https://example.com/test")!)
    wait(for: [expectation], timeout: 1.0)
}
```

### 7. Event Tracker Tests (~25 tests)

**Event Tracking**
- ✅ Track event with name only
- ✅ Track event with properties
- ✅ Track revenue event (amount, currency)
- ✅ Event data serialization
- ✅ Install ID included in request
- ✅ Timestamp formatting (ISO 8601)

**Validation**
- ✅ Reject empty event name
- ✅ Reject invalid property types
- ✅ Reject nil install ID
- ✅ Reject negative revenue

**Offline Queueing**
- ✅ Queue events when offline
- ✅ Flush queue when online
- ✅ Queue size limit (100 events)
- ✅ FIFO order preservation
- ✅ Queue persistence to disk

**Retry Logic**
- ✅ Retry failed events
- ✅ Exponential backoff
- ✅ Max retry count (3)
- ✅ Discard after max retries

**Test Example**:
```swift
func testTrackEventWithProperties() async throws {
    let mockNetwork = MockNetworkManager()
    let mockStorage = MockStorageManager()
    mockStorage.savedInstallId = "test-install-id"

    let tracker = EventTracker(network: mockNetwork, storage: mockStorage)

    try await tracker.trackEvent(name: "purchase", properties: ["amount": 29.99, "product": "Widget"])

    XCTAssertEqual(mockNetwork.lastRequest?.eventName, "purchase")
    XCTAssertEqual(mockNetwork.lastRequest?.installId, "test-install-id")
    XCTAssertEqual(mockNetwork.lastRequest?.eventData["amount"] as? Double, 29.99)
}

func testQueueEventWhenOffline() async {
    let mockNetwork = MockNetworkManager()
    mockNetwork.simulateOffline = true

    let tracker = EventTracker(network: mockNetwork, storage: MockStorageManager())

    try? await tracker.trackEvent(name: "test_event")

    XCTAssertEqual(tracker.queuedEventCount, 1)
}
```

### 8. LinkForty SDK Tests (~40 tests)

**Initialization**
- ✅ Initialize with valid config
- ✅ Reject invalid base URL
- ✅ Prevent double initialization
- ✅ First launch detection
- ✅ Install reporting on first launch
- ✅ Load cached data on subsequent launch

**Public API**
- ✅ `initialize(config:)` success
- ✅ `initialize(config:)` failure (invalid config)
- ✅ `onDeferredDeepLink(_:)` registration
- ✅ `onDeepLink(_:)` registration
- ✅ `trackEvent(name:properties:)` success
- ✅ `trackEvent(name:properties:)` failure (not initialized)
- ✅ `getInstallData()` returns cached data
- ✅ `getInstallId()` returns cached ID
- ✅ `clearData()` clears all cached data

**Thread Safety**
- ✅ Concurrent initialization attempts
- ✅ Concurrent event tracking
- ✅ Concurrent callback registration

**Integration**
- ✅ Full initialization flow (first launch)
- ✅ Full initialization flow (existing user)
- ✅ Deferred deep link callback invoked
- ✅ Direct deep link callback invoked

**Test Example**:
```swift
func testInitializeFirstLaunch() async throws {
    let sdk = LinkForty.shared
    let config = LinkFortyConfig(baseURL: URL(string: "https://example.com")!, apiKey: nil, debug: true, attributionWindowHours: 168)

    try await sdk.initialize(config: config)

    XCTAssertNotNil(sdk.getInstallId())
}

func testPreventDoubleInitialization() async {
    let sdk = LinkForty.shared
    let config = LinkFortyConfig(baseURL: URL(string: "https://example.com")!)

    try? await sdk.initialize(config: config)

    do {
        try await sdk.initialize(config: config)
        XCTFail("Should throw alreadyInitialized error")
    } catch LinkFortyError.alreadyInitialized {
        // Expected
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
```

## Integration Testing Strategy

### Target: 50+ Tests

### 1. Backend Integration Tests (~30 tests)

**Prerequisites**:
- Local LinkForty Core instance running on `localhost:3000`
- Test database with clean state
- Test API key for Cloud tests

**LinkForty Core Integration**
- ✅ POST /api/sdk/v1/install (attributed response)
- ✅ POST /api/sdk/v1/install (organic response)
- ✅ POST /api/sdk/v1/event (success)
- ✅ POST /api/sdk/v1/event (invalid install ID)
- ✅ GET /.well-known/apple-app-site-association

**LinkForty Cloud Integration**
- ✅ Authenticated requests (valid API key)
- ✅ Authenticated requests (invalid API key)
- ✅ Rate limiting behavior
- ✅ Organization-scoped data

**Attribution Flow**
- ✅ Create link via backend API
- ✅ Simulate click with fingerprint
- ✅ Report install with matching fingerprint
- ✅ Verify attribution (confidence score >= 70%)
- ✅ Report install with non-matching fingerprint
- ✅ Verify organic install

**Test Example**:
```swift
func testAttributionFlowEndToEnd() async throws {
    // 1. Create link via Core API
    let linkId = try await createTestLink(shortCode: "test123", iosUrl: "myapp://product/456")

    // 2. Simulate click with known fingerprint
    let fingerprint = DeviceFingerprint(
        userAgent: "TestAgent",
        timezone: "America/New_York",
        language: "en-US",
        screenWidth: 1170,
        screenHeight: 2532,
        platform: "iOS",
        platformVersion: "15.0"
    )
    try await simulateClick(linkId: linkId, fingerprint: fingerprint)

    // 3. Report install with matching fingerprint
    let sdk = LinkForty.shared
    let config = LinkFortyConfig(baseURL: URL(string: "http://localhost:3000")!)
    try await sdk.initialize(config: config)

    // 4. Verify attribution
    let installData = sdk.getInstallData()
    XCTAssertNotNil(installData)
    XCTAssertEqual(installData?.shortCode, "test123")
}
```

### 2. Deep Link Integration Tests (~20 tests)

**Universal Links**
- ✅ Handle Universal Link when app installed
- ✅ Handle Universal Link cold start
- ✅ Handle Universal Link warm start
- ✅ Parse parameters from Universal Link
- ✅ Verify AASA file accessibility

**Custom URL Schemes**
- ✅ Handle custom scheme URL (myapp://...)
- ✅ Parse parameters from custom scheme
- ✅ Handle malformed scheme URLs

**Test Example**:
```swift
func testUniversalLinkHandling() async throws {
    let sdk = LinkForty.shared
    let expectation = XCTestExpectation(description: "Deep link callback")

    sdk.onDeepLink { url, data in
        XCTAssertEqual(data?.shortCode, "abc123")
        XCTAssertEqual(data?.utmParameters?.source, "email")
        expectation.fulfill()
    }

    // Simulate Universal Link
    let url = URL(string: "https://go.example.com/abc123?utm_source=email")!
    sdk.handleUniversalLink(url)

    await fulfillment(of: [expectation], timeout: 2.0)
}
```

## Performance Testing Strategy

### Target: 20+ Tests

### 1. Initialization Performance (~5 tests)

**Benchmarks**:
- ✅ Cold start initialization: < 50ms
- ✅ Warm start initialization: < 20ms
- ✅ First launch (with network): < 500ms
- ✅ Subsequent launch (cache hit): < 50ms

**Test Example**:
```swift
func testInitializationPerformance() {
    measure {
        let sdk = LinkForty.shared
        let config = LinkFortyConfig(baseURL: URL(string: "https://example.com")!)
        try? await sdk.initialize(config: config)
    }

    // Assert < 50ms average
}
```

### 2. Memory Performance (~5 tests)

**Benchmarks**:
- ✅ Idle memory footprint: < 2MB
- ✅ Active tracking memory: < 3MB
- ✅ Event queue (100 events): < 1MB
- ✅ No memory leaks

**Test with Instruments**:
- Allocations instrument
- Leaks instrument
- VM Tracker

### 3. Network Performance (~5 tests)

**Benchmarks**:
- ✅ Install report: < 1 second (good network)
- ✅ Event tracking: < 500ms (good network)
- ✅ Retry delay: Exponential backoff verified
- ✅ Concurrent requests: < 3 concurrent at a time

### 4. Battery Performance (~5 tests)

**Benchmarks**:
- ✅ Background CPU usage: < 1%
- ✅ Network requests: Batched when possible
- ✅ No continuous polling

**Test with Instruments**:
- Energy Log instrument

## Privacy & Security Testing

### Target: 15+ Tests (100% Coverage)

### 1. Privacy Compliance (~10 tests)

**No Persistent Identifiers**
- ✅ Verify no IDFA collected without consent
- ✅ Verify no IDFV stored permanently
- ✅ Verify no MAC address collection
- ✅ Verify no device serial number

**Data Minimization**
- ✅ Only necessary fingerprint data collected
- ✅ No location data (GPS) collected
- ✅ No contact list access
- ✅ No photo library access

**Privacy Manifest Validation**
- ✅ PrivacyInfo.xcprivacy declares all collected data
- ✅ NSPrivacyCollectedDataTypes accurate
- ✅ NSPrivacyAccessedAPITypes accurate
- ✅ NSPrivacyTrackingDomains empty (no tracking)

**Test Example**:
```swift
func testNoIDFACollectedWithoutConsent() {
    let collector = FingerprintCollector()
    let fingerprint = collector.collectFingerprint()

    XCTAssertNil(fingerprint.idfa, "IDFA should not be collected without explicit consent")
}

func testPrivacyManifestExists() {
    let bundle = Bundle(for: LinkForty.self)
    let privacyManifestUrl = bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")

    XCTAssertNotNil(privacyManifestUrl, "Privacy manifest must exist")
}
```

### 2. Security Testing (~5 tests)

**HTTPS Enforcement**
- ✅ Reject HTTP base URLs in production
- ✅ Allow HTTP for localhost (testing only)
- ✅ Certificate pinning (future enhancement)

**Authentication**
- ✅ API key sent via Authorization header (not URL)
- ✅ API key not logged in debug mode
- ✅ No credentials stored in plain text

**Test Example**:
```swift
func testRejectHTTPInProduction() {
    let config = LinkFortyConfig(baseURL: URL(string: "http://example.com")!)

    XCTAssertThrowsError(try LinkForty.shared.initialize(config: config)) { error in
        XCTAssertEqual(error as? LinkFortyError, .invalidConfiguration)
    }
}

func testAPIKeyNotInURL() {
    let network = NetworkManager(config: LinkFortyConfig(baseURL: URL(string: "https://example.com")!, apiKey: "secret"))

    let request = network.buildRequest(endpoint: "/test", method: .get, body: nil, headers: nil)

    XCTAssertFalse(request.url?.absoluteString.contains("secret") ?? true)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
}
```

## UI/E2E Testing Strategy

### Target: 10+ Tests

### 1. Example App UI Tests (~10 tests)

**Basic Flow**
- ✅ Launch app, verify SDK initializes
- ✅ Tap "Track Event" button, verify success message
- ✅ Display install data on screen
- ✅ Handle deep link, navigate to correct screen

**Error Scenarios**
- ✅ Invalid configuration, display error
- ✅ Network error, display retry option
- ✅ No attribution, display organic install

**Test Example**:
```swift
func testTrackEventButton() {
    let app = XCUIApplication()
    app.launch()

    let trackButton = app.buttons["Track Event"]
    XCTAssertTrue(trackButton.exists)

    trackButton.tap()

    let successLabel = app.staticTexts["Event Tracked"]
    XCTAssertTrue(successLabel.waitForExistence(timeout: 2))
}
```

## Test Data & Fixtures

### Mock Data

**Mock Install Response (Attributed)**:
```json
{
  "installId": "mock-install-id-123",
  "attributed": true,
  "confidenceScore": 85,
  "matchedFactors": ["userAgent", "timezone", "screenResolution"],
  "deepLinkData": {
    "shortCode": "abc123",
    "iosURL": "myapp://product/456",
    "utmParameters": {
      "source": "facebook",
      "campaign": "summer-sale"
    },
    "customParameters": {
      "productId": "456"
    }
  }
}
```

**Mock Install Response (Organic)**:
```json
{
  "installId": "mock-install-id-456",
  "attributed": false,
  "confidenceScore": 0,
  "matchedFactors": [],
  "deepLinkData": null
}
```

### Test Fixtures Location
- `Tests/LinkFortySDKTests/Fixtures/`
  - `AttributedInstallResponse.json`
  - `OrganicInstallResponse.json`
  - `EventTrackingSuccess.json`
  - `ErrorResponses/401Unauthorized.json`
  - `ErrorResponses/500ServerError.json`

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: xcodebuild test -scheme LinkFortySDK -destination 'platform=iOS Simulator,name=iPhone 15'
      - name: Upload Coverage to Codecov
        uses: codecov/codecov-action@v3
```

### Test Execution Strategy

**On Every Commit**:
- Run all unit tests
- Run SwiftLint
- Generate coverage report

**On Pull Request**:
- Run all unit tests
- Run integration tests (against local Core)
- Run performance tests
- Run privacy tests

**Before Release**:
- Run full test suite (unit + integration + E2E)
- Run on all supported iOS versions (13-18)
- Run on physical devices
- Run performance benchmarks
- Run security audit

## Code Coverage Targets

| Component | Target Coverage | Priority |
|-----------|-----------------|----------|
| Models | 100% | High |
| Storage Manager | 95% | High |
| Network Manager | 90% | High |
| Fingerprint Collector | 100% | Critical (privacy) |
| Attribution Manager | 85% | High |
| Deep Link Handler | 85% | High |
| Event Tracker | 85% | High |
| LinkForty SDK | 80% | High |
| **Overall** | **80%+** | **High** |

## Test Maintenance

### Test Code Quality
- Use descriptive test names (`testReportInstallAttributedResponse` not `testReportInstall1`)
- Follow Arrange-Act-Assert pattern
- One assertion per test (when possible)
- No conditional logic in tests
- No test interdependencies

### Test Documentation
- Document complex test setups
- Explain why tests exist (not just what they do)
- Document known limitations

### Test Refactoring
- Extract common test utilities
- Use test fixtures for mock data
- Reuse mock objects across tests
- Regular cleanup of obsolete tests

## Success Criteria

### Definition of Done (Testing)
- [ ] 200+ unit tests written
- [ ] 50+ integration tests written
- [ ] 10+ UI tests written
- [ ] 80%+ code coverage achieved
- [ ] All tests passing on CI/CD
- [ ] Performance benchmarks met
- [ ] Privacy tests 100% passing
- [ ] Zero critical security issues
- [ ] Tested on iOS 13-18
- [ ] Tested on iPhone and iPad
- [ ] Tested on physical devices
