import XCTest
@testable import MempoolMonitor

final class MempoolSpaceAPITests: XCTestCase {

    // MARK: - SUT

    private var mockNetwork: MockNetworkManager!
    private var sut: MempoolSpaceAPI!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkManager()
        sut = MempoolSpaceAPI(network: mockNetwork)
    }

    override func tearDown() {
        mockNetwork = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private static let pricesJSON = Data("""
    {
        "time": 1714000000,
        "USD": 63500,
        "EUR": 58900,
        "GBP": 50100,
        "CAD": 86700,
        "CHF": 57500,
        "AUD": 97200,
        "JPY": 9826500
    }
    """.utf8)

    private static let difficultyJSON = Data("""
    {
        "progressPercent": 45.2,
        "difficultyChange": -3.2,
        "estimatedRetargetDate": 1714500000,
        "remainingBlocks": 1234,
        "remainingTime": 8643210,
        "previousRetarget": 5.1,
        "previousTime": 1712000000,
        "nextRetargetHeight": 841824,
        "timeAvg": 590000,
        "timeOffset": -50000,
        "expectedBlocks": 1008
    }
    """.utf8)

    private static let blockJSON = Data("""
    {
        "id": "0000000000000000000320e4b6e2c5a8c4faf0e9e0b9a7b6c5d4e3f2a1b0c9d8",
        "height": 840000,
        "version": 536928260,
        "timestamp": 1713571767,
        "bits": 386085586,
        "nonce": 2545774367,
        "difficulty": 83148355189739.02,
        "merkle_root": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
        "tx_count": 3721,
        "size": 1620188,
        "weight": 3993440,
        "previousblockhash": "000000000000000000024bfa6cfc23a0c0d58e8e37ef3b37b870b5c6cf25a1f",
        "mediantime": 1713568854,
        "stale": false
    }
    """.utf8)

    private static let feesJSON = Data("""
    {
        "fastestFee": 21,
        "halfHourFee": 18,
        "hourFee": 15,
        "economyFee": 12,
        "minimumFee": 1
    }
    """.utf8)

    private static let transactionJSON = Data("""
    {
        "txid": "15e10745f15593a899cef391191bdd3d7c12412cc4696b7bcb669d0feadc8521",
        "version": 1,
        "locktime": 0,
        "vin": [],
        "vout": [
            { "value": 15000 },
            { "value": 5000 }
        ],
        "size": 884,
        "weight": 3536,
        "fee": 20000,
        "status": {
            "confirmed": true,
            "block_height": 363348,
            "block_hash": "0000000000000000139385d7aa78ffb45469e0c715b8d6ea6cb2ffa98acc7171",
            "block_time": 1435754650
        }
    }
    """.utf8)

    // MARK: - fetchPrices — Endpoint

    func test_fetchPrices_callsCorrectEndpoint() async throws {
        mockNetwork.stubbedResponseData = Self.pricesJSON
        try await sut.fetchPrices()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://mempool.space/api/v1/prices")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_fetchPrices_callsPerformExactlyOnce() async throws {
        mockNetwork.stubbedResponseData = Self.pricesJSON
        try await sut.fetchPrices()

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    func test_fetchPrices_sendsNoBody() async throws {
        mockNetwork.stubbedResponseData = Self.pricesJSON
        try await sut.fetchPrices()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertNil(request.httpBody, "GET request should not include a body")
    }

    func test_fetchPrices_decodesResponseCorrectly() async throws {
        mockNetwork.stubbedResponseData = Self.pricesJSON
        let response = try await sut.fetchPrices()

        XCTAssertEqual(response.time, 1714000000)
        XCTAssertEqual(response.usd, 63500)
        XCTAssertEqual(response.eur, 58900)
        XCTAssertEqual(response.gbp, 50100)
        XCTAssertEqual(response.cad, 86700)
        XCTAssertEqual(response.chf, 57500)
        XCTAssertEqual(response.aud, 97200)
        XCTAssertEqual(response.jpy, 9826500)
    }

    func test_fetchPrices_decodesUppercaseCurrencyKeys() async throws {
        // Verifies that CodingKeys map "USD" → usd, "EUR" → eur, etc.
        mockNetwork.stubbedResponseData = Self.pricesJSON
        let response = try await sut.fetchPrices()

        XCTAssertGreaterThan(response.usd, 0)
        XCTAssertGreaterThan(response.eur, 0)
    }

    func test_fetchPrices_propagatesNetworkError() async {
        mockNetwork.stubbedError = HTTPError.networkError(URLError(.notConnectedToInternet))

        await assertThrowsHTTPError(.networkError(URLError(.notConnectedToInternet))) {
            try await self.sut.fetchPrices()
        }
    }

    func test_fetchPrices_propagatesServerError() async {
        mockNetwork.stubbedError = HTTPError.internalServerError

        await assertThrowsHTTPError(.internalServerError) {
            try await self.sut.fetchPrices()
        }
    }

    // MARK: - fetchDifficultyAdjustment — Endpoint

    func test_fetchDifficultyAdjustment_callsCorrectEndpoint() async throws {
        mockNetwork.stubbedResponseData = Self.difficultyJSON
        try await sut.fetchDifficultyAdjustment()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://mempool.space/api/v1/difficulty-adjustment")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_fetchDifficultyAdjustment_callsPerformExactlyOnce() async throws {
        mockNetwork.stubbedResponseData = Self.difficultyJSON
        try await sut.fetchDifficultyAdjustment()

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    func test_fetchDifficultyAdjustment_decodesResponseCorrectly() async throws {
        mockNetwork.stubbedResponseData = Self.difficultyJSON
        let response = try await sut.fetchDifficultyAdjustment()

        XCTAssertEqual(response.progressPercent, 45.2, accuracy: 0.001)
        XCTAssertEqual(response.difficultyChange, -3.2, accuracy: 0.001)
        XCTAssertEqual(response.estimatedRetargetDate, 1714500000)
        XCTAssertEqual(response.remainingBlocks, 1234)
        XCTAssertEqual(response.remainingTime, 8643210)
        XCTAssertEqual(response.previousRetarget, 5.1, accuracy: 0.001)
        XCTAssertEqual(response.previousTime, 1712000000)
        XCTAssertEqual(response.nextRetargetHeight, 841824)
        XCTAssertEqual(response.timeAvg, 590000)
        XCTAssertEqual(response.timeOffset, -50000)
        XCTAssertEqual(response.expectedBlocks, 1008, accuracy: 0.001)
    }

    func test_fetchDifficultyAdjustment_propagatesNotFoundError() async {
        mockNetwork.stubbedError = HTTPError.notFound

        await assertThrowsHTTPError(.notFound) {
            try await self.sut.fetchDifficultyAdjustment()
        }
    }

    // MARK: - fetchBlock — Endpoint

    func test_fetchBlock_callsCorrectEndpoint() async throws {
        let hash = "0000000000000000000320e4b6e2c5a8"
        mockNetwork.stubbedResponseData = Self.blockJSON
        try await sut.fetchBlock(hash: hash)

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://mempool.space/api/v1/block/\(hash)")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_fetchBlock_callsPerformExactlyOnce() async throws {
        mockNetwork.stubbedResponseData = Self.blockJSON
        try await sut.fetchBlock(hash: "abc")

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    func test_fetchBlock_sendsNoBody() async throws {
        mockNetwork.stubbedResponseData = Self.blockJSON
        try await sut.fetchBlock(hash: "abc")

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertNil(request.httpBody, "GET request should not include a body")
    }

    func test_fetchBlock_decodesResponseCorrectly() async throws {
        mockNetwork.stubbedResponseData = Self.blockJSON
        let response = try await sut.fetchBlock(hash: "0000000000000000000320e4b6e2c5a8c4faf0e9e0b9a7b6c5d4e3f2a1b0c9d8")

        XCTAssertEqual(response.height, 840000)
        XCTAssertEqual(response.version, 536928260)
        XCTAssertEqual(response.timestamp, 1713571767)
        XCTAssertEqual(response.nonce, 2545774367)
        XCTAssertEqual(response.txCount, 3721)
        XCTAssertEqual(response.size, 1620188)
        XCTAssertEqual(response.weight, 3993440)
        XCTAssertEqual(response.medianTime, 1713568854)
        XCTAssertFalse(response.stale)
    }

    func test_fetchBlock_decodesSnakeCaseKeys() async throws {
        // Verifies CodingKeys: merkle_root → merkleRoot, tx_count → txCount,
        // previousblockhash → previousBlockHash, mediantime → medianTime
        mockNetwork.stubbedResponseData = Self.blockJSON
        let response = try await sut.fetchBlock(hash: "abc")

        XCTAssertEqual(response.merkleRoot, "abc123def456abc123def456abc123def456abc123def456abc123def456abc1")
        XCTAssertEqual(response.txCount, 3721)
        XCTAssertEqual(response.previousBlockHash, "000000000000000000024bfa6cfc23a0c0d58e8e37ef3b37b870b5c6cf25a1f")
        XCTAssertEqual(response.medianTime, 1713568854)
    }

    func test_fetchBlock_propagatesNotFoundError() async {
        mockNetwork.stubbedError = HTTPError.notFound

        await assertThrowsHTTPError(.notFound) {
            try await self.sut.fetchBlock(hash: "invalidhash")
        }
    }

    func test_fetchBlock_propagatesServerError() async {
        mockNetwork.stubbedError = HTTPError.internalServerError

        await assertThrowsHTTPError(.internalServerError) {
            try await self.sut.fetchBlock(hash: "abc")
        }
    }

    // MARK: - fetchRecommendedFees — Endpoint

    func test_fetchRecommendedFees_callsCorrectEndpoint() async throws {
        mockNetwork.stubbedResponseData = Self.feesJSON
        try await sut.fetchRecommendedFees()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://mempool.space/api/v1/fees/recommended")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_fetchRecommendedFees_callsPerformExactlyOnce() async throws {
        mockNetwork.stubbedResponseData = Self.feesJSON
        try await sut.fetchRecommendedFees()

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    func test_fetchRecommendedFees_sendsNoBody() async throws {
        mockNetwork.stubbedResponseData = Self.feesJSON
        try await sut.fetchRecommendedFees()

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertNil(request.httpBody, "GET request should not include a body")
    }

    func test_fetchRecommendedFees_decodesResponseCorrectly() async throws {
        mockNetwork.stubbedResponseData = Self.feesJSON
        let response = try await sut.fetchRecommendedFees()

        XCTAssertEqual(response.fastestFee, 21)
        XCTAssertEqual(response.halfHourFee, 18)
        XCTAssertEqual(response.hourFee, 15)
        XCTAssertEqual(response.economyFee, 12)
        XCTAssertEqual(response.minimumFee, 1)
    }

    func test_fetchRecommendedFees_propagatesNetworkError() async {
        mockNetwork.stubbedError = HTTPError.networkError(URLError(.timedOut))

        await assertThrowsHTTPError(.networkError(URLError(.timedOut))) {
            try await self.sut.fetchRecommendedFees()
        }
    }

    func test_fetchRecommendedFees_propagatesServerError() async {
        mockNetwork.stubbedError = HTTPError.internalServerError

        await assertThrowsHTTPError(.internalServerError) {
            try await self.sut.fetchRecommendedFees()
        }
    }

    // MARK: - fetchTransaction — Endpoint

    func test_fetchTransaction_callsCorrectEndpoint() async throws {
        let txId = "15e10745f15593a899cef391191bdd3d7c12412cc4696b7bcb669d0feadc8521"
        mockNetwork.stubbedResponseData = Self.transactionJSON
        try await sut.fetchTransaction(txId: txId)

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://mempool.space/api/tx/\(txId)")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_fetchTransaction_callsPerformExactlyOnce() async throws {
        mockNetwork.stubbedResponseData = Self.transactionJSON
        try await sut.fetchTransaction(txId: "abc")

        XCTAssertEqual(mockNetwork.callCount, 1)
    }

    func test_fetchTransaction_sendsNoBody() async throws {
        mockNetwork.stubbedResponseData = Self.transactionJSON
        try await sut.fetchTransaction(txId: "abc")

        let request = try XCTUnwrap(mockNetwork.capturedRequests.first)
        XCTAssertNil(request.httpBody, "GET request should not include a body")
    }

    func test_fetchTransaction_decodesResponseCorrectly() async throws {
        mockNetwork.stubbedResponseData = Self.transactionJSON
        let response = try await sut.fetchTransaction(txId: "15e10745f15593a899cef391191bdd3d7c12412cc4696b7bcb669d0feadc8521")

        XCTAssertEqual(response.txid, "15e10745f15593a899cef391191bdd3d7c12412cc4696b7bcb669d0feadc8521")
        XCTAssertEqual(response.version, 1)
        XCTAssertEqual(response.locktime, 0)
        XCTAssertEqual(response.size, 884)
        XCTAssertEqual(response.weight, 3536)
        XCTAssertEqual(response.fee, 20000)
        XCTAssertEqual(response.vout.count, 2)
        XCTAssertEqual(response.vout[0].value, 15000)
        XCTAssertEqual(response.vout[1].value, 5000)
    }

    func test_fetchTransaction_decodesSnakeCaseStatusKeys() async throws {
        // Verifies CodingKeys: block_height → blockHeight, block_hash → blockHash, block_time → blockTime
        mockNetwork.stubbedResponseData = Self.transactionJSON
        let response = try await sut.fetchTransaction(txId: "abc")

        XCTAssertTrue(response.status.confirmed)
        XCTAssertEqual(response.status.blockHeight, 363348)
        XCTAssertEqual(response.status.blockHash, "0000000000000000139385d7aa78ffb45469e0c715b8d6ea6cb2ffa98acc7171")
        XCTAssertEqual(response.status.blockTime, 1435754650)
    }

    func test_fetchTransaction_propagatesNotFoundError() async {
        mockNetwork.stubbedError = HTTPError.notFound

        await assertThrowsHTTPError(.notFound) {
            try await self.sut.fetchTransaction(txId: "invalidtxid")
        }
    }

    func test_fetchTransaction_propagatesNetworkError() async {
        mockNetwork.stubbedError = HTTPError.networkError(URLError(.notConnectedToInternet))

        await assertThrowsHTTPError(.networkError(URLError(.notConnectedToInternet))) {
            try await self.sut.fetchTransaction(txId: "abc")
        }
    }
}
