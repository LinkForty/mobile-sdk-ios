//
//  AttributionManagerTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import XCTest
@testable import LinkFortySDK

@available(iOS 13.0, macOS 10.15, *)
final class AttributionManagerTests: XCTestCase {
    var sut: AttributionManager!
    var mockNetworkManager: MockNetworkManager!
    var mockStorageManager: MockStorageManager!
    var mockFingerprintCollector: MockFingerprintCollector!

    override func setUp() {
        super.setUp()
        mockNetworkManager = MockNetworkManager()
        mockStorageManager = MockStorageManager()
        mockFingerprintCollector = MockFingerprintCollector()

        sut = AttributionManager(
            networkManager: mockNetworkManager,
            storageManager: mockStorageManager,
            fingerprintCollector: mockFingerprintCollector
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkManager = nil
        mockStorageManager = nil
        mockFingerprintCollector = nil
        super.tearDown()
    }

    // MARK: - Install Attribution Tests

    func testReportInstallAttributedResponse() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "test-install-id-123",
            attributed: true,
            confidenceScore: 85.0,
            matchedFactors: ["userAgent", "timezone", "screenResolution"],
            deepLinkData: DeepLinkData(
                shortCode: "abc123",
                iosURL: "myapp://product/456",
                utmParameters: UTMParameters(source: "facebook", campaign: "summer")
            )
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        let response = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(response.installId, "test-install-id-123")
        XCTAssertTrue(response.attributed)
        XCTAssertEqual(response.confidenceScore, 85.0)
        XCTAssertEqual(response.matchedFactors.count, 3)
        XCTAssertNotNil(response.deepLinkData)
        XCTAssertEqual(response.deepLinkData?.shortCode, "abc123")
    }

    func testReportInstallOrganicResponse() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "organic-install-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        let response = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(response.installId, "organic-install-id")
        XCTAssertFalse(response.attributed)
        XCTAssertEqual(response.confidenceScore, 0)
        XCTAssertTrue(response.matchedFactors.isEmpty)
        XCTAssertNil(response.deepLinkData)
    }

    func testReportInstallCachesInstallId() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "cached-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(mockStorageManager.savedInstallId, "cached-id")
    }

    func testReportInstallCachesDeepLinkDataWhenAttributed() async throws {
        // Arrange
        let deepLinkData = DeepLinkData(
            shortCode: "test123",
            iosURL: "myapp://test"
        )

        let expectedResponse = InstallResponse(
            installId: "test-id",
            attributed: true,
            confidenceScore: 90,
            matchedFactors: ["userAgent"],
            deepLinkData: deepLinkData
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertNotNil(mockStorageManager.savedInstallData)
        XCTAssertEqual(mockStorageManager.savedInstallData?.shortCode, "test123")
    }

    func testReportInstallDoesNotCacheDeepLinkDataWhenOrganic() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "organic-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertNil(mockStorageManager.savedInstallData)
    }

    func testReportInstallMarksHasLaunched() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "test-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertTrue(mockStorageManager.hasLaunchedCalled)
    }

    func testReportInstallCollectsFingerprint() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "test-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertTrue(mockFingerprintCollector.collectCalled)
        XCTAssertEqual(mockFingerprintCollector.lastAttributionWindow, 168)
    }

    func testReportInstallWithDeviceId() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "test-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(
            attributionWindowHours: 168,
            deviceId: "test-device-id"
        )

        // Assert
        XCTAssertEqual(mockFingerprintCollector.lastDeviceId, "test-device-id")
    }

    func testReportInstallSendsCorrectEndpoint() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "test-id",
            attributed: false,
            confidenceScore: 0,
            matchedFactors: [],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = expectedResponse

        // Act
        _ = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertEqual(mockNetworkManager.lastEndpoint, "/api/sdk/v1/install")
        XCTAssertEqual(mockNetworkManager.lastMethod, .post)
    }

    // MARK: - Network Error Tests

    func testReportInstallNetworkError() async {
        // Arrange
        mockNetworkManager.mockError = LinkFortyError.networkError(
            NSError(domain: "test", code: -1)
        )

        // Act & Assert
        do {
            _ = try await sut.reportInstall(attributionWindowHours: 168)
            XCTFail("Should throw error")
        } catch {
            // Expected
            XCTAssertNotNil(error)
        }
    }

    func testReportInstallInvalidResponse() async {
        // Arrange
        mockNetworkManager.mockError = LinkFortyError.invalidResponse(
            statusCode: 500,
            message: "Server error"
        )

        // Act & Assert
        do {
            _ = try await sut.reportInstall(attributionWindowHours: 168)
            XCTFail("Should throw error")
        } catch let error as LinkFortyError {
            if case .invalidResponse(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Data Retrieval Tests

    func testGetInstallIdReturnsStoredValue() {
        // Arrange
        mockStorageManager.mockInstallId = "stored-id"

        // Act
        let installId = sut.getInstallId()

        // Assert
        XCTAssertEqual(installId, "stored-id")
    }

    func testGetInstallIdReturnsNilWhenNotStored() {
        // Arrange
        mockStorageManager.mockInstallId = nil

        // Act
        let installId = sut.getInstallId()

        // Assert
        XCTAssertNil(installId)
    }

    func testGetInstallDataReturnsStoredValue() {
        // Arrange
        let testData = DeepLinkData(
            shortCode: "abc123",
            iosURL: "myapp://test"
        )
        mockStorageManager.mockInstallData = testData

        // Act
        let data = sut.getInstallData()

        // Assert
        XCTAssertEqual(data?.shortCode, "abc123")
    }

    func testGetInstallDataReturnsNilWhenNotStored() {
        // Arrange
        mockStorageManager.mockInstallData = nil

        // Act
        let data = sut.getInstallData()

        // Assert
        XCTAssertNil(data)
    }

    func testIsFirstLaunchReturnsTrueInitially() {
        // Arrange
        mockStorageManager.mockIsFirstLaunch = true

        // Act
        let isFirst = sut.isFirstLaunch()

        // Assert
        XCTAssertTrue(isFirst)
    }

    func testIsFirstLaunchReturnsFalseAfterLaunch() {
        // Arrange
        mockStorageManager.mockIsFirstLaunch = false

        // Act
        let isFirst = sut.isFirstLaunch()

        // Assert
        XCTAssertFalse(isFirst)
    }

    // MARK: - Clear Data Tests

    func testClearDataCallsStorageClearAll() {
        // Act
        sut.clearData()

        // Assert
        XCTAssertTrue(mockStorageManager.clearAllCalled)
    }

    // MARK: - Attribution Scenarios

    func testHighConfidenceAttribution() async throws {
        // Arrange
        let response = InstallResponse(
            installId: "id",
            attributed: true,
            confidenceScore: 95,
            matchedFactors: ["userAgent", "timezone", "screenResolution", "language"],
            deepLinkData: DeepLinkData(shortCode: "high-conf")
        )

        mockNetworkManager.mockResponse = response

        // Act
        let result = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertTrue(result.attributed)
        XCTAssertGreaterThan(result.confidenceScore, 70)
        XCTAssertNotNil(result.deepLinkData)
    }

    func testLowConfidenceNoAttribution() async throws {
        // Arrange
        let response = InstallResponse(
            installId: "id",
            attributed: false,
            confidenceScore: 45,
            matchedFactors: ["timezone"],
            deepLinkData: nil
        )

        mockNetworkManager.mockResponse = response

        // Act
        let result = try await sut.reportInstall(attributionWindowHours: 168)

        // Assert
        XCTAssertFalse(result.attributed)
        XCTAssertLessThan(result.confidenceScore, 70)
        XCTAssertNil(result.deepLinkData)
    }
}
