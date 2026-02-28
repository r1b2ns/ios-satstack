import XCTest
@testable import MempoolMonitor

final class MempoolMonitorAPITests: XCTestCase {

    // MARK: - SUT

    private var mockNetwork: MockNetworkManager!
    private var sut: MempoolMonitorAPI!

    private let baseURL = URL(string: "http://192.168.15.33:3000")!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkManager()
        mockNetwork.stubbedResponseData = Self.validResponseJSON
        sut = MempoolMonitorAPI(baseURL: baseURL, network: mockNetwork)
    }

    private static let validResponseJSON = Data("""
    {
        "confirmations": 0,
        "status": "pending",
        "txId": "abc123",
        "valueBtc": 0.5,
        "feeSats": 1200
    }
    """.utf8)

    override func tearDown() {
        mockNetwork = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Endpoint

    func test_watchTransaction_postsToCorrectEndpoint() async throws {
        try await sut.watchTransaction(txId: "abc123", deviceToken: "device456", activityToken: nil)

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.15.33:3000/tx/watch")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func test_watchTransaction_callsPerformExactlyOnce() async throws {
        try await sut.watchTransaction(txId: "abc123", deviceToken: "device456", activityToken: nil)

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    // MARK: - Headers

    func test_watchTransaction_setsContentTypeHeader() async throws {
        try await sut.watchTransaction(txId: "abc123", deviceToken: "device456", activityToken: nil)

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Payload

    func test_watchTransaction_encodesTxIdAndDeviceToken() async throws {
        try await sut.watchTransaction(txId: "txid_abc", deviceToken: "token_xyz", activityToken: nil)

        let body = try requestBody()
        XCTAssertEqual(body["txId"] as? String, "txid_abc")
        XCTAssertEqual(body["deviceToken"] as? String, "token_xyz")
    }

    func test_watchTransaction_withActivityToken_includesItInPayload() async throws {
        try await sut.watchTransaction(txId: "txid_abc", deviceToken: "token_xyz", activityToken: "live_token_123")

        let body = try requestBody()
        XCTAssertEqual(body["activityToken"] as? String, "live_token_123")
    }

    func test_watchTransaction_withoutActivityToken_omitsKeyFromPayload() async throws {
        try await sut.watchTransaction(txId: "txid_abc", deviceToken: "token_xyz", activityToken: nil)

        let body = try requestBody()
        XCTAssertNil(body["activityToken"], "activityToken should be omitted from JSON when nil")
    }

    // MARK: - Error Propagation

    func test_watchTransaction_propagatesNetworkError() async {
        mockNetwork.stubbedError = HTTPError.networkError(URLError(.notConnectedToInternet))

        do {
            try await sut.watchTransaction(txId: "abc", deviceToken: "def", activityToken: nil)
            XCTFail("Expected the error to be propagated")
        } catch HTTPError.networkError {
            // ✓
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_watchTransaction_propagatesServerError() async {
        mockNetwork.stubbedError = HTTPError.internalServerError

        await assertThrowsHTTPError(.internalServerError) {
            try await self.sut.watchTransaction(txId: "abc", deviceToken: "def", activityToken: nil)
        }
    }

    // MARK: - Response

    func test_watchTransaction_decodesResponseCorrectly() async throws {
        let response = try await sut.watchTransaction(txId: "abc123", deviceToken: "device456", activityToken: nil)

        XCTAssertEqual(response.confirmations, 0)
        XCTAssertEqual(response.status, .pending)
        XCTAssertEqual(response.txId, "abc123")
        XCTAssertEqual(response.valueBtc, 0.5)
        XCTAssertEqual(response.feeSats, 1200)
    }

    // MARK: - BaseURL

    func test_watchTransaction_usesInjectedBaseURL() async throws {
        let customURL = URL(string: "http://custom.host:9000")!
        sut = MempoolMonitorAPI(baseURL: customURL, network: mockNetwork)

        try await sut.watchTransaction(txId: "abc", deviceToken: "def", activityToken: nil)

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertTrue(
            request.url?.absoluteString.hasPrefix("http://custom.host:9000") == true,
            "Request should use the injected baseURL"
        )
    }

    // MARK: - Helpers

    private func requestBody(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let request = try XCTUnwrap(mockNetwork.capturedRequests.first, file: file, line: line)
        let data    = try XCTUnwrap(request.httpBody, file: file, line: line)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            file: file, line: line
        )
    }
}
