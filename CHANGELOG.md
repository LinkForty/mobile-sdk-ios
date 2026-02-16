# Changelog

All notable changes to the LinkForty iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
