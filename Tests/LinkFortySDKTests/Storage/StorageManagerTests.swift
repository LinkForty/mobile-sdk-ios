//
//  StorageManagerTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

final class StorageManagerTests: XCTestCase {
    var sut: StorageManager!
    var mockUserDefaults: MockUserDefaults!

    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        sut = StorageManager(userDefaults: mockUserDefaults)
    }

    override func tearDown() {
        sut = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Install ID Tests

    func testSaveAndRetrieveInstallId() {
        // Arrange
        let testId = "test-install-id-123"

        // Act
        sut.saveInstallId(testId)
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        let retrieved = sut.getInstallId()

        // Assert
        XCTAssertEqual(retrieved, testId)
    }

    func testGetInstallIdReturnsNilWhenNotSet() {
        // Act
        let retrieved = sut.getInstallId()

        // Assert
        XCTAssertNil(retrieved)
    }

    func testSaveInstallIdOverwritesExisting() {
        // Arrange
        let firstId = "first-id"
        let secondId = "second-id"

        // Act
        sut.saveInstallId(firstId)
        Thread.sleep(forTimeInterval: 0.1)
        sut.saveInstallId(secondId)
        Thread.sleep(forTimeInterval: 0.1)
        let retrieved = sut.getInstallId()

        // Assert
        XCTAssertEqual(retrieved, secondId)
    }

    // MARK: - Install Data Tests

    func testSaveAndRetrieveInstallData() {
        // Arrange
        let testData = DeepLinkData(
            shortCode: "abc123",
            iosURL: "myapp://product/456",
            utmParameters: UTMParameters(source: "facebook", campaign: "summer")
        )

        // Act
        sut.saveInstallData(testData)
        Thread.sleep(forTimeInterval: 0.1)
        let retrieved = sut.getInstallData()

        // Assert
        XCTAssertEqual(retrieved, testData)
        XCTAssertEqual(retrieved?.shortCode, "abc123")
        XCTAssertEqual(retrieved?.iosURL, "myapp://product/456")
        XCTAssertEqual(retrieved?.utmParameters?.source, "facebook")
    }

    func testGetInstallDataReturnsNilWhenNotSet() {
        // Act
        let retrieved = sut.getInstallData()

        // Assert
        XCTAssertNil(retrieved)
    }

    func testSaveInstallDataWithAllFields() {
        // Arrange
        let testData = DeepLinkData(
            shortCode: "test123",
            iosURL: "https://example.com/test",
            androidURL: "https://example.com/android",
            webURL: "https://example.com/web",
            utmParameters: UTMParameters(
                source: "google",
                medium: "cpc",
                campaign: "spring",
                term: "shoes",
                content: "banner"
            ),
            customParameters: ["productId": "789", "color": "blue"],
            clickedAt: Date(),
            linkId: "link-uuid-123"
        )

        // Act
        sut.saveInstallData(testData)
        Thread.sleep(forTimeInterval: 0.1)
        let retrieved = sut.getInstallData()

        // Assert
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.shortCode, "test123")
        XCTAssertEqual(retrieved?.iosURL, "https://example.com/test")
        XCTAssertEqual(retrieved?.androidURL, "https://example.com/android")
        XCTAssertEqual(retrieved?.webURL, "https://example.com/web")
        XCTAssertEqual(retrieved?.utmParameters?.source, "google")
        XCTAssertEqual(retrieved?.utmParameters?.medium, "cpc")
        XCTAssertEqual(retrieved?.customParameters?["productId"], "789")
        XCTAssertEqual(retrieved?.linkId, "link-uuid-123")
    }

    // MARK: - First Launch Tests

    func testIsFirstLaunchReturnsTrueInitially() {
        // Act
        let isFirst = sut.isFirstLaunch()

        // Assert
        XCTAssertTrue(isFirst)
    }

    func testIsFirstLaunchReturnsFalseAfterSetHasLaunched() {
        // Act
        sut.setHasLaunched()
        Thread.sleep(forTimeInterval: 0.1)
        let isFirst = sut.isFirstLaunch()

        // Assert
        XCTAssertFalse(isFirst)
    }

    func testFirstLaunchFlagPersists() {
        // Act
        sut.setHasLaunched()
        Thread.sleep(forTimeInterval: 0.1)

        // Create new storage manager with same UserDefaults
        let newSut = StorageManager(userDefaults: mockUserDefaults)
        let isFirst = newSut.isFirstLaunch()

        // Assert
        XCTAssertFalse(isFirst)
    }

    // MARK: - Clear Data Tests

    func testClearAllRemovesAllData() {
        // Arrange
        sut.saveInstallId("test-id")
        sut.saveInstallData(DeepLinkData(shortCode: "abc"))
        sut.setHasLaunched()
        Thread.sleep(forTimeInterval: 0.1)

        // Act
        sut.clearAll()
        Thread.sleep(forTimeInterval: 0.1)

        // Assert
        XCTAssertNil(sut.getInstallId())
        XCTAssertNil(sut.getInstallData())
        XCTAssertTrue(sut.isFirstLaunch()) // Should be first launch again
    }

    func testClearAllDoesNotCrashWhenNoDataExists() {
        // Act & Assert
        XCTAssertNoThrow(sut.clearAll())
        Thread.sleep(forTimeInterval: 0.1)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentReadsAndWrites() {
        // Arrange
        let expectation = expectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 20

        // Act
        for i in 0..<10 {
            DispatchQueue.global().async {
                self.sut.saveInstallId("id-\(i)")
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.sut.getInstallId()
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(sut.getInstallId())
    }
}

// MARK: - Mock UserDefaults

class MockUserDefaults: UserDefaultsProtocol {
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "mock.userdefaults")

    func set(_ value: Any?, forKey key: String) {
        queue.async {
            self.storage[key] = value
        }
    }

    func string(forKey key: String) -> String? {
        queue.sync {
            storage[key] as? String
        }
    }

    func data(forKey key: String) -> Data? {
        queue.sync {
            storage[key] as? Data
        }
    }

    func bool(forKey key: String) -> Bool {
        queue.sync {
            (storage[key] as? Bool) ?? false
        }
    }

    func removeObject(forKey key: String) {
        queue.async {
            self.storage.removeValue(forKey: key)
        }
    }
}
