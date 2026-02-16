# Changelog

All notable changes to the LinkForty iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

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
