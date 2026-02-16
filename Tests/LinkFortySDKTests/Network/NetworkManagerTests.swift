//
//  NetworkManagerTests.swift
//  LinkFortySDKTests
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

@testable import LinkFortySDK
import XCTest

final class NetworkManagerTests: XCTestCase {
    var sut: NetworkManager!
    var mockSession: MockURLSession!
    var config: LinkFortyConfig!

    override func setUp() {
        super.setUp()
        config = LinkFortyConfig(
            baseURL: URL(string: "https://api.example.com")!,
            apiKey: "test-api-key",
            debug: false
        )
        mockSession = MockURLSession()
        sut = NetworkManager(config: config, session: mockSession)
    }

    override func tearDown() {
        sut = nil
        mockSession = nil
        config = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func testSuccessfulGetRequest() async throws {
        // Arrange
        let expectedResponse = InstallResponse(
            installId: "test-id",
            attributed: true,
            confidenceScore: 85,
            matchedFactors: ["userAgent", "timezone"],
            deepLinkData: DeepLinkData(shortCode: "abc123")
        )

        mockSession.mockData = try JSONEncoder().encode(expectedResponse)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let result: InstallResponse = try await sut.request(
            endpoint: "/test",
            method: .get
        )

        // Assert
        XCTAssertEqual(result.installId, "test-id")
        XCTAssertEqual(result.attributed, true)
        XCTAssertEqual(result.confidenceScore, 85)
    }

    func testSuccessfulPostRequestWithBody() async throws {
        // Arrange
        struct TestRequest: Codable {
            let name: String
            let value: Int
        }

        struct TestResponse: Codable {
            let success: Bool
        }

        let requestBody = TestRequest(name: "test", value: 42)
        let expectedResponse = TestResponse(success: true)

        mockSession.mockData = try JSONEncoder().encode(expectedResponse)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let result: TestResponse = try await sut.request(
            endpoint: "/test",
            method: .post,
            body: requestBody
        )

        // Assert
        XCTAssertTrue(result.success)
        XCTAssertNotNil(mockSession.lastRequest?.httpBody)
    }

    // MARK: - Authentication Tests

    func testRequestIncludesAuthorizationHeader() async throws {
        // Arrange
        struct TestResponse: Codable {
            let ok: Bool
        }

        mockSession.mockData = try JSONEncoder().encode(TestResponse(ok: true))
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let _: TestResponse = try await sut.request(
            endpoint: "/test",
            method: .get
        )

        // Assert
        let authHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer test-api-key")
    }

    func testRequestWithoutApiKeyHasNoAuthHeader() async throws {
        // Arrange
        let configWithoutKey = LinkFortyConfig(
            baseURL: URL(string: "https://api.example.com")!,
            apiKey: nil
        )
        let sutWithoutKey = NetworkManager(config: configWithoutKey, session: mockSession)

        struct TestResponse: Codable {
            let ok: Bool
        }

        mockSession.mockData = try JSONEncoder().encode(TestResponse(ok: true))
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let _: TestResponse = try await sutWithoutKey.request(
            endpoint: "/test",
            method: .get
        )

        // Assert
        let authHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(authHeader)
    }

    // MARK: - Error Tests

    func testNetworkError() async {
        // Arrange
        mockSession.mockError = NSError(domain: "test", code: -1)

        // Act & Assert
        do {
            struct TestResponse: Codable { let ok: Bool }
            let _: TestResponse = try await sut.request(endpoint: "/test", method: .get)
            XCTFail("Should throw error")
        } catch let error as LinkFortyError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test400ClientError() async {
        // Arrange
        mockSession.mockData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        // Act & Assert
        do {
            struct TestResponse: Codable { let ok: Bool }
            let _: TestResponse = try await sut.request(endpoint: "/test", method: .get)
            XCTFail("Should throw error")
        } catch let error as LinkFortyError {
            if case .invalidResponse(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test401UnauthorizedError() async {
        // Arrange
        mockSession.mockData = Data("Unauthorized".utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        // Act & Assert
        do {
            struct TestResponse: Codable { let ok: Bool }
            let _: TestResponse = try await sut.request(endpoint: "/test", method: .get)
            XCTFail("Should throw error")
        } catch let error as LinkFortyError {
            if case .invalidResponse(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 401)
                XCTAssertEqual(message, "Unauthorized")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test500ServerError() async {
        // Arrange
        mockSession.mockData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        // Act & Assert
        do {
            struct TestResponse: Codable { let ok: Bool }
            let _: TestResponse = try await sut.request(endpoint: "/test", method: .get)
            XCTFail("Should throw error")
        } catch let error as LinkFortyError {
            if case .invalidResponse(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidJSONResponse() async {
        // Arrange
        mockSession.mockData = Data("not json".utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act & Assert
        do {
            struct TestResponse: Codable { let ok: Bool }
            let _: TestResponse = try await sut.request(endpoint: "/test", method: .get)
            XCTFail("Should throw error")
        } catch let error as LinkFortyError {
            if case .decodingError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Headers Tests

    func testCustomHeaders() async throws {
        // Arrange
        struct TestResponse: Codable {
            let ok: Bool
        }

        mockSession.mockData = try JSONEncoder().encode(TestResponse(ok: true))
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let _: TestResponse = try await sut.request(
            endpoint: "/test",
            method: .get,
            headers: ["X-Custom-Header": "custom-value"]
        )

        // Assert
        let customHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "X-Custom-Header")
        XCTAssertEqual(customHeader, "custom-value")
    }

    func testContentTypeHeader() async throws {
        // Arrange
        struct TestResponse: Codable {
            let ok: Bool
        }

        mockSession.mockData = try JSONEncoder().encode(TestResponse(ok: true))
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        let _: TestResponse = try await sut.request(
            endpoint: "/test",
            method: .post,
            body: ["key": "value"]
        )

        // Assert
        let contentType = mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType, "application/json")
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let error = mockError {
            throw error
        }

        guard let data = mockData, let response = mockResponse else {
            throw NSError(domain: "MockURLSession", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No mock data or response configured"
            ])
        }

        return (data, response)
    }
}
