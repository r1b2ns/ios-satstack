import Foundation

// MARK: - Response

/// Top-level response for `GET /tx/{txId}`.
struct MempoolTransactionResponse: Decodable {

    /// Transaction ID (hex).
    let txid: String

    /// Transaction version.
    let version: Int

    /// Locktime value.
    let locktime: Int

    /// Transaction size in bytes.
    let size: Int

    /// Transaction weight in weight units.
    let weight: Int

    /// Miner fee in satoshis.
    let fee: Int

    /// List of transaction outputs.
    let vout: [MempoolTxVout]

    /// Confirmation status of the transaction.
    let status: MempoolTxStatus
}

/// A single transaction output.
struct MempoolTxVout: Decodable {

    /// Output value in satoshis.
    let value: Int
}

/// Confirmation details embedded in a transaction response.
struct MempoolTxStatus: Decodable {

    /// Whether the transaction has been confirmed in a block.
    let confirmed: Bool

    /// Block height at which the transaction was confirmed, if applicable.
    let blockHeight: Int?

    /// Hash of the confirming block, if applicable.
    let blockHash: String?

    /// Unix timestamp of the confirming block, if applicable.
    let blockTime: Int?

    enum CodingKeys: String, CodingKey {
        case confirmed
        case blockHeight = "block_height"
        case blockHash   = "block_hash"
        case blockTime   = "block_time"
    }
}

// MARK: - Request

/// `GET /tx/{txId}` — fetches metadata and confirmation status for a Bitcoin transaction.
struct GetMempoolTransactionRequest: Requestable {

    typealias Response = MempoolTransactionResponse

    /// Transaction ID to look up (64-character hex string).
    let txId: String

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/tx/\(txId)" }
    var method: HTTPMethod { .get }
}
