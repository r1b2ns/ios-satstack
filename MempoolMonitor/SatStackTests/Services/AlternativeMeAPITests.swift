import XCTest
@testable import SatStack

final class AlternativeMeAPITests: XCTestCase {

    // MARK: - SUT

    private var mockNetwork: MockNetworkManager!
    private var sut: AlternativeMeAPI!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkManager()
        mockNetwork.stubbedResponseData = Self.validResponseJSON
        sut = AlternativeMeAPI(network: mockNetwork)
    }

    override func tearDown() {
        mockNetwork = nil
        sut = nil
        super.tearDown()
    }

    private static let validResponseJSON = Data("""
    {
        "name": "Fear and Greed Index",
        "data": [
            {
                "value": "72",
                "value_classification": "Greed",
                "timestamp": "1772323200",
                "time_until_update": "53346"
            }
        ],
        "metadata": {
            "error": null
        }
    }
    """.utf8)

    // MARK: - Endpoint

    func test_fetchFearAndGreedIndex_callsCorrectEndpoint() async throws {
        try await sut.fetchFearAndGreedIndex()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.alternative.me/fng/")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_fetchFearAndGreedIndex_callsPerformExactlyOnce() async throws {
        try await sut.fetchFearAndGreedIndex()

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    // MARK: - Headers

    func test_fetchFearAndGreedIndex_setsContentTypeHeader() async throws {
        try await sut.fetchFearAndGreedIndex()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Body

    func test_fetchFearAndGreedIndex_sendsNoBody() async throws {
        try await sut.fetchFearAndGreedIndex()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertNil(request.httpBody, "GET request should not include a body")
    }

    // MARK: - Response

    func test_fetchFearAndGreedIndex_decodesResponseCorrectly() async throws {
        let response = try await sut.fetchFearAndGreedIndex()

        XCTAssertEqual(response.name, "Fear and Greed Index")
        XCTAssertEqual(response.data.count, 1)
        let entry = try XCTUnwrap(response.data.first)
        XCTAssertEqual(entry.value, "72")
        XCTAssertEqual(entry.valueClassification, "Greed")
        XCTAssertEqual(entry.timestamp, "1772323200")
        XCTAssertEqual(entry.timeUntilUpdate, "53346")
    }

    func test_fetchFearAndGreedIndex_decodesNullMetadataError() async throws {
        let response = try await sut.fetchFearAndGreedIndex()

        XCTAssertNil(response.metadata.error)
    }

    func test_fetchFearAndGreedIndex_decodesSnakeCaseKeys() async throws {
        // Given — response with absent time_until_update (optional field)
        mockNetwork.stubbedResponseData = Data("""
        {
            "name": "Fear and Greed Index",
            "data": [
                {
                    "value": "14",
                    "value_classification": "Extreme Fear",
                    "timestamp": "1772323200"
                }
            ],
            "metadata": { "error": null }
        }
        """.utf8)

        let response = try await sut.fetchFearAndGreedIndex()

        let entry = try XCTUnwrap(response.data.first)
        XCTAssertEqual(entry.valueClassification, "Extreme Fear")
        XCTAssertNil(entry.timeUntilUpdate, "time_until_update should be nil when absent")
    }

    // MARK: - Error Propagation

    func test_fetchFearAndGreedIndex_propagatesNetworkError() async {
        mockNetwork.stubbedError = HTTPError.networkError(URLError(.notConnectedToInternet))

        do {
            try await sut.fetchFearAndGreedIndex()
            XCTFail("Expected the error to be propagated")
        } catch HTTPError.networkError {
            // ✓
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_fetchFearAndGreedIndex_propagatesServerError() async {
        mockNetwork.stubbedError = HTTPError.internalServerError

        await assertThrowsHTTPError(.internalServerError) {
            try await self.sut.fetchFearAndGreedIndex()
        }
    }

    func test_fetchFearAndGreedIndex_propagatesNotFoundError() async {
        mockNetwork.stubbedError = HTTPError.notFound

        await assertThrowsHTTPError(.notFound) {
            try await self.sut.fetchFearAndGreedIndex()
        }
    }
}
