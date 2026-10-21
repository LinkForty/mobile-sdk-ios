# Changelog

All notable changes to the LinkForty iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [1.5.0] - 2026-10-20
### Fixed
- The install is reported once per installation. `initialize()` previously reported an install on every launch, so each launch within the attribution window recorded a new install matched to the same click, and the deferred deep link was delivered again. Once an install ID is stored, `initialize()` now returns the cached attribution without a request, and `onDeferredDeepLink` fires only on the launch that reported the install. The attribution stays available from `getInstallData()` ([#9](https://github.com/LinkForty/mobile-sdk-ios/pull/9)).
- `LinkForty.shared.isFirstLaunch()` can be called before `initialize()` and stays true for the whole first launch. It previously returned `true` before initialization whatever the stored state, and `false` as soon as `initialize()` had reported the install ([#9](https://github.com/LinkForty/mobile-sdk-ios/pull/9)).
- `trackEvent`, `trackRevenue` and `trackScreenView` succeed when the server stores the event. The SDK expected a `success` field the event endpoint has never sent, so every call threw a decoding error and queued an event the server had already stored, and each `flushEvents()` sent the queue again ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `flushEvents()` sends each queued event once, in order, and returns when they are sent. Events stay queued only after a network error or a 5xx; an event the server rejects (4xx) is dropped instead of being retried on every flush ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- Network errors that can succeed on another attempt (timeout, no connection, host unreachable, DNS failure) are retried with the same backoff as 5xx responses. A cancelled task is no longer reported as a network error ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- A failed `initialize()` (for example, offline on first launch) leaves the SDK uninitialized, so `initialize()` can be called again in the same session. It previously stayed half-initialized: a retry threw `alreadyInitialized` and events threw `notInitialized` until the app was restarted ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `LinkFortyConfig.attributionWindowHours` is sent with the install. `initialize(config:attributionWindowHours:)` used its own default of 168 hours whatever the config said; the parameter now defaults to the config's value ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `onDeferredDeepLink` and `onDeepLink` callbacks registered before `initialize()` are kept. They were silently discarded ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- A link passed to `handleDeepLink(url:)` before `initialize()` has configured the SDK, as when a Universal Link launches the app, is held and resolved once it has. It was discarded ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- Deep link parameters that aren't strings (numbers, booleans, objects) are delivered in their string form. One such parameter made the whole deep link fail to decode: an attributed install delivered no deferred deep link, and a direct open fell back to the local URL parse without `linkId` or `deepLinkPath` ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `DeepLinkData.clickedAt` is set: timestamps with fractional seconds, which the server sends, are parsed ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `clearData()` keeps the app's registered callbacks ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `createLink` with a `templateId` returns the server's short URL when the server provides one, so it carries the link's own domain ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `LinkFortyConfig.debug` turns on the SDK's logging ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).
- `createLink` with a `templateId` records the external user ID. It posted to `/api/links`, which ignores `externalUserId`, so the link had no user and wasn't deduplicated per user. Every `createLink` now posts to `/api/sdk/v1/links`, which accepts `templateId`, and falls back to `/api/links` only when the server doesn't have the SDK endpoint (404) ([#11](https://github.com/LinkForty/mobile-sdk-ios/pull/11)).

### Changed
- `onDeferredDeepLink` is called with `nil` on the launch that reports an organic (unattributed) install, as documented. It was previously called only for attributed installs, so code in an app's organic branch never ran; that code now runs once, on the first launch ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).

### Added
- An end-to-end test app and driver under `E2E/` that run an app on a simulator against a LinkForty server and check what the SDK delivers and what the server stores. See `E2E/README.md` ([#10](https://github.com/LinkForty/mobile-sdk-ios/pull/10)).

## [1.4.2] - 2026-10-19
### Fixed
- The device language is sent as `language` or `language-REGION` (`en-GB`, `zh-CN`, `es-419`) on the install request and the `fp_lang` resolve parameter. `Locale.identifier` keywords for region, calendar and number settings (`en_GB@rg=eszzzz`, `en_US@calendar=japanese`) and script subtags (`zh-Hans_CN`) are no longer included, so the value matches what a browser on the same device sends in `Accept-Language` ([#7](https://github.com/LinkForty/mobile-sdk-ios/pull/7)).

## [1.4.1] - 2026-09-09
### Fixed
- URL parameters appended to a link are now delivered on a **direct open** (app already installed), not just after a deferred install. A link shared as `?slug=titanic` previously returned only the link's stored configuration on a direct open, because `resolveURL` discarded the local parse of the tapped URL. `customParameters` now carries both, with URL values winning on a collision — the same precedence the server applies on the deferred path. `linkId`, `deepLinkPath`, `appScheme`, the store URLs and `utmParameters` remain server-provided ([#6](https://github.com/LinkForty/mobile-sdk-ios/pull/6)).
- The reserved-parameter filter now excludes `fp_*` and `lf_click` in addition to the five UTM keys, matching the server. Fingerprint signals and the click-correlation id could previously reach an app inside `customParameters` as if the customer had set them ([#6](https://github.com/LinkForty/mobile-sdk-ios/pull/6)).
- `InstallResponse` no longer fails to decode when the backend returns `deepLinkData: {}` for an organic (unattributed) install, which surfaced as a decoding error from `initialize()`. An empty or otherwise unusable `deepLinkData` object is now treated as "no deep link" (`nil`), the same as `null` ([#2](https://github.com/LinkForty/mobile-sdk-ios/issues/2)).

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
