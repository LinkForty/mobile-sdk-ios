# Changelog

All notable changes to the LinkForty iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.4.0] - 2026-06-11
### Added
- The SDK now identifies itself on every request: a `sdkName` (`"ios"`) and `sdkVersion` field is included on the install and event payloads, and an `X-LinkForty-SDK: ios/<version>` header is sent on all requests. This lets the backend report which SDKs and versions are in use and flag outdated integrations. No API or integration changes are required.
- **Last-click attribution for in-app events.** Every tracked event is now stamped with the deep link that most recently opened the app (deferred install *or* direct re-engagement) plus an app-open `sessionId`, so the backend can credit in-app activity to the originating link. The newest deep-link open supersedes the previous one, and the active link is persisted across app restarts; events with no preceding deep-link open stay organic (session only). Fully automatic — no API or integration changes are required.
- **Screen-view tracking** for per-link screen-flow funnels. New `LinkForty.shared.trackScreenView(name:)` (UIKit, e.g. from `viewDidAppear`) and a SwiftUI `.linkfortyScreen("Name")` view modifier emit a `screen_view` event (carrying the screen name, the previous screen, and the active attribution stamp). Each call is one line; no navigation swizzling.

## [1.3.0] - 2026-05-04
### Added
- `appToken` parameter on `LinkFortyConfig` for LinkForty Cloud organic-install attribution. The token is a public, workspace-scoped identifier (format: `at_<32 hex>`) safe to ship in your app bundle. When provided, it's sent on the install request so Cloud can scope organic installs (App Store discovery, social mentions, etc.) to your workspace. Self-hosted Core ignores the field. Find your token in the Cloud dashboard under Workspace Settings → App Token.
- `setExternalUserId(_:)` and `getExternalUserId()` on `LinkForty` for SDK-level user attribution. The set value is automatically attached to all `createLink()` calls (unless overridden per-call via `CreateLinkOptions.externalUserId`), enabling per-user deduplication and share attribution on the dashboard. Pass `nil` to clear. The value is stored in memory only and is cleared by `clearData()` and `reset()`.

## [1.2.0] - 2026-03-03
### Added
- Added `externalUserId` parameter to `CreateLinkOptions` for per-user deduplication and share attribution
- Added `deduplicated` field to `CreateLinkResult` indicating when an existing link was returned

## [1.1.3] - 2026-02-16
- Minimum deployment target bumped from iOS 13.0 to iOS 16.0
- Minimum Xcode version bumped from 14.0 to 15.0
## [1.1.2] - 2026-02-16
---
### Changed
- Split `DeepLinkHandlerTests.swift` into `DeepLinkHandlerTests.swift` and `DeepLinkServerResolutionTests.swift` to satisfy SwiftLint `file_length` rule
---
## [1.1.1] - 2026-02-16
### Added
- 28 new unit tests covering server-side URL resolution, link creation models, `DeepLinkData` model (initialization, JSON encoding/decoding, CodingKeys, Equatable, round-trip), and pre-initialization error handling
- `NetworkManagerProtocol` and `FingerprintCollectorProtocol` conformance on `DeepLinkHandler` to enable dependency injection for testing
- Shared `MockFingerprintCollector` test helper in `TestHelpers/MockHelpers.swift`
- `clickedAt` and `linkId` fields on `DeepLinkData`
- `invalidDeepLinkURL` error case on `LinkFortyError`
- Link creation section in example app (`LinkCreationSection`) with display of `deepLinkPath`, `appScheme`, and `linkId`

### Changed
- `DeepLinkHandler` now uses protocol types (`NetworkManagerProtocol`, `FingerprintCollectorProtocol`) instead of concrete types for dependency injection
- `StorageManager` debug logging now uses `LinkFortyLogger` instead of raw `print()` calls
- CI test matrix updated from iOS 15/16/17 to iOS 16/17/18 on macOS 15 with Xcode 16
- Replaced `.data(using: .utf8)!` with `Data(_:utf8)` initializer across test files

### Fixed
- SwiftLint `no_print` custom rule regex changed from `print\(` to `\bprint\(` to prevent false positives on methods like `collectFingerprint()`
- SwiftLint configuration: removed contradictory `line_length` disable, removed overly strict `force_unwrapping` opt-in rule, added `non_optional_string_data_conversion` opt-in rule
- Sorted imports in all 11 test files to satisfy SwiftLint `sorted_imports` rule
- Example app bugs: `shortCode` treated as optional when non-optional, `customParameters.isEmpty` called on optional without unwrapping
- API documentation (`API.md`): corrected `shortCode` type from `String?` to `String`, `customParameters` from `[String: String]` to `[String: String]?`, removed stale `createdAt`/`expiresAt` fields, added missing types and error cases

### Removed
- iOS 15 support from CI test matrix

---
## [1.1.0] - 2026-02-16
### Added
- `createLink(options:)` method for programmatic short link creation from the app
- `CreateLinkOptions` and `CreateLinkResult` public types
- `missingApiKey` error case on `LinkFortyError`
- Server-side URL resolution in `handleDeepLink(url:)` via `GET /api/sdk/v1/resolve/{shortCode}` with device fingerprint query parameters — returns enriched deep link data including custom parameters, deep link path, and app scheme
- `deepLinkPath` and `appScheme` fields on `DeepLinkData`

### Changed
- `DeepLinkHandler` now accepts a `NetworkManager` and `FingerprintCollector` via `configure()` for server-side resolution, with automatic fallback to local URL parsing on failure

---

## [1.0.0] - 2025-01-15

### Added
- Initial release
- Deferred deep linking with probabilistic fingerprinting
- Universal Links support
- Custom URL scheme support
- Event tracking with offline queueing
- Privacy-first design (no IDFA)
- Swift Package Manager support
- CocoaPods support
- Comprehensive documentation
- Example apps

### Security
- HTTPS enforcement for API endpoints
- Bearer token authentication
- Privacy manifest included

---

**Note**: This changelog will be updated as development progresses.
