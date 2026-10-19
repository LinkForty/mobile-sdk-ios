//
//  InstallLocaleTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

/// The install request under device locales whose identifiers carry scripts and
/// `@` keywords. `initialize()` builds its collector from `Locale.current`, so the
/// install flow is exercised one level down: `AttributionManager.reportInstall`
/// with a real `FingerprintCollector` (given the locale) and a real
/// `NetworkManager` over a stubbed session. CI also runs the whole suite under
/// several simulator languages and regions, which `testCurrentLocaleProducesLanguageTag`
/// checks against `Locale.current`.
@available(iOS 13.0, macOS 10.15, *)
final class InstallLocaleTests: XCTestCase {
    /// `language` or `language-REGION`, at most 10 characters.
    private static let languageTagPattern = "^[a-z]{2,3}(-([A-Z]{2}|[0-9]{3}))?$"

    private static let cases: [(identifier: String, expected: String)] = [
        ("en_GB@rg=eszzzz", "en-GB"),
        ("en_US@calendar=japanese", "en-US"),
        ("en_US@numbers=arab", "en-US"),
        ("zh_Hans_CN", "zh-CN"),
        ("sr_Latn_RS", "sr-RS"),
        ("ar_SA", "ar-SA"),
        ("he_IL", "he-IL"),
        ("es_419", "es-419"),
        ("fil_PH", "fil-PH"),
        ("ja_JP@calendar=japanese", "ja-JP"),
        ("th_TH@numbers=thai", "th-TH")
    ]

    func testInstallRequestCarriesLanguageTagForEveryLocale() async throws {
        for testCase in Self.cases {
            let session = MockURLSession()
            session.mockData = try JSONEncoder().encode(
                InstallResponse(
                    installId: "install-\(testCase.expected)",
                    attributed: false,
                    confidenceScore: 0,
                    matchedFactors: [],
                    deepLinkData: nil
                )
            )
            session.mockResponse = HTTPURLResponse(
                url: URL(string: "https://api.example.com/api/sdk/v1/install")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )

            let manager = AttributionManager(
                networkManager: NetworkManager(
                    config: LinkFortyConfig(baseURL: URL(string: "https://api.example.com")!),
                    session: session
                ),
                storageManager: MockStorageManager(),
                fingerprintCollector: FingerprintCollector(
                    device: MockUIDevice(),
                    screen: MockUIScreen(),
                    bundle: MockBundle(),
                    locale: Locale(identifier: testCase.identifier),
                    timeZone: TimeZone(identifier: "Europe/Madrid")!
                )
            )

            let response = try await manager.reportInstall(attributionWindowHours: 168)
            XCTAssertEqual(response.installId, "install-\(testCase.expected)", testCase.identifier)

            let request = try XCTUnwrap(session.lastRequest, testCase.identifier)
            XCTAssertEqual(request.url?.path, "/api/sdk/v1/install", testCase.identifier)
            let body = try XCTUnwrap(request.httpBody, testCase.identifier)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any],
                testCase.identifier
            )
            let language = try XCTUnwrap(json["language"] as? String, testCase.identifier)

            XCTAssertEqual(language, testCase.expected, testCase.identifier)
            assertLanguageTag(language, context: testCase.identifier)
        }
    }

    func testCurrentLocaleProducesLanguageTag() {
        let identifier = Locale.current.identifier
        let fingerprint = FingerprintCollector().collectFingerprint(
            attributionWindowHours: 168,
            deviceId: nil,
            appToken: nil
        )

        assertLanguageTag(fingerprint.language, context: identifier)
    }

    private func assertLanguageTag(_ language: String, context: String, line: UInt = #line) {
        XCTAssertLessThanOrEqual(language.count, 10, context, line: line)
        XCTAssertNotNil(
            language.range(of: Self.languageTagPattern, options: .regularExpression),
            "\(language) is not language or language-REGION (\(context))",
            line: line
        )
    }
}
