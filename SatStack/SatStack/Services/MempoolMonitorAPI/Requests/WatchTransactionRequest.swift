import Foundation

// MARK: - Response

/// Server response for `POST /tx/watch`.
struct WatchTransactionResponse: Codable, Equatable {
    let confirmations: Int
    let status: TransactionStatus
    let txId: String
    let valueBtc: Double?
    let feeSats: Int?
    /// Estimated minutes until first confirmation, provided by the server (nil when confirmed).
    let estimatedMinutes: Int?
    /// Sender address (first input) as returned by the server.
    let senderAddress: String?
    /// Position of the transaction in the mempool block queue.
    let blockPosition: BlockPosition?
}

// MARK: - Request

/// `POST /tx/watch` — registers a Bitcoin transaction for monitoring.
struct WatchTransactionRequest: Requestable {

    typealias Response = WatchTransactionResponse

    // MARK: - Input

    let baseURL:       URL
    let apiKey:        String
    let txId:          String
    let deviceToken:   String
    let activityToken: String?  // nil → omitted from JSON by the encoder

    // MARK: - Requestable

    var path:   String     { "/tx/watch" }
    var method: HTTPMethod { .post }

    /// Sends `X-API-Key` when the key is non-empty; omits the header otherwise.
    var headers: [String: String] {
        apiKey.isEmpty ? [:] : ["X-API-Key": apiKey]
    }

    var body: (any Encodable)? {
        Payload(txId: txId, deviceToken: deviceToken, activityToken: activityToken)
    }

    // MARK: - Private

    private struct Payload: Encodable {
        let txId:          String
        let deviceToken:   String
        let activityToken: String?  // `nil` → key absent from JSON
    }
}
