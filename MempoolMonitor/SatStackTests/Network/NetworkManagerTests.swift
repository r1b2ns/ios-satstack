import XCTest
@testable import SatStack

final class NetworkManagerTests: XCTestCase {

    // MARK: - SUT

    private var sut: NetworkManager!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        sut = NetworkManager(session: URLSession(configuration: config))
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Success

    func test_perform_success_decodesResponseBody() async throws {
        // Given
        let expected = StubResponse(id: 42)
        MockURLProtocol.requestHandler = { _ in
            let data = try JSONEncoder().encode(expected)
            return (.stub(statusCode: 200), data)
        }

        // When
        let result = try await sut.perform(StubRequest())

        // Then
        XCTAssertEqual(result, expected)
    }

    func test_perform_emptyBody_returnsEmptyResponse() async throws {
        // Given – 204 No Content with empty body
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 204), Data()) }

        // When / Then – should not throw
        _ = try await sut.perform(StubEmptyRequest())
    }

    // MARK: - HTTP 4xx Errors

    func test_perform_400_throwsBadRequest() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 400), Data()) }
        await assertThrowsHTTPError(.badRequest) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    func test_perform_401_throwsUnauthorized() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 401), Data()) }
        await assertThrowsHTTPError(.unauthorized) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    func test_perform_403_throwsForbidden() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 403), Data()) }
        await assertThrowsHTTPError(.forbidden) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    func test_perform_404_throwsNotFound() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 404), Data()) }
        await assertThrowsHTTPError(.notFound) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    func test_perform_429_throwsTooManyRequests() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 429), Data()) }
        await assertThrowsHTTPError(.tooManyRequests) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    // MARK: - HTTP 5xx Errors

    func test_perform_500_throwsInternalServerError() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 500), Data()) }
        await assertThrowsHTTPError(.internalServerError) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    func test_perform_503_throwsServiceUnavailable() async {
        MockURLProtocol.requestHandler = { _ in (.stub(statusCode: 503), Data()) }
        await assertThrowsHTTPError(.serviceUnavailable) { _ = try await self.sut.perform(StubEmptyRequest()) }
    }

    // MARK: - Network and Decoding Errors

    func test_perform_networkError_throwsHTTPNetworkError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await sut.perform(StubEmptyRequest())
            XCTFail("Expected HTTPError.networkError")
        } catch HTTPError.networkError {
            // ✓
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_perform_invalidJSON_throwsDecodingError() async {
        // StubRequest expects `StubResponse`, but receives invalid JSON
        MockURLProtocol.requestHandler = { _ in
            (.stub(statusCode: 200), Data("not json".utf8))
        }

        do {
            _ = try await sut.perform(StubRequest())
            XCTFail("Expected HTTPError.decodingError")
        } catch HTTPError.decodingError {
            // ✓
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - URLRequest Construction

    func test_perform_buildsCorrectURL() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            return (.stub(statusCode: 204), Data())
        }

        _ = try await sut.perform(StubEmptyRequest())

        XCTAssertEqual(captured?.url?.absoluteString, "https://api.example.com/items")
    }

    func test_perform_setsHTTPMethod() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            return (.stub(statusCode: 204), Data())
        }

        _ = try await sut.perform(StubEmptyRequest())

        XCTAssertEqual(captured?.httpMethod, "GET")
    }

    func test_perform_injectsContentTypeHeader() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            return (.stub(statusCode: 204), Data())
        }

        _ = try await sut.perform(StubEmptyRequest())

        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}
