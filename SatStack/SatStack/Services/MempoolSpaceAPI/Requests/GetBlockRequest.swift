import Foundation

// MARK: - Response

/// Top-level response for `GET /v1/block/{blockHash}`.
struct BlockResponse: Decodable {

    /// Block hash (same as the requested `blockHash`).
    let id: String

    /// Block height in the chain.
    let height: Int

    /// Block version field.
    let version: Int

    /// Unix timestamp of when the block was mined.
    let timestamp: Int

    /// Compact representation of the difficulty target.
    let bits: Int

    /// Nonce used to mine the block.
    let nonce: Int

    /// Mining difficulty at this block.
    let difficulty: Double

    /// Merkle root of all transactions in the block.
    let merkleRoot: String

    /// Number of transactions included in the block.
    let txCount: Int

    /// Block size in bytes.
    let size: Int

    /// Block weight in weight units.
    let weight: Int

    /// Hash of the previous block.
    let previousBlockHash: String

    /// Median timestamp of the 11 blocks before this one (used for locktime).
    let medianTime: Int

    /// Whether this block is on a stale (orphaned) chain.
    let stale: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case height
        case version
        case timestamp
        case bits
        case nonce
        case difficulty
        case merkleRoot       = "merkle_root"
        case txCount          = "tx_count"
        case size
        case weight
        case previousBlockHash = "previousblockhash"
        case medianTime       = "mediantime"
        case stale
    }
}

// MARK: - Request

/// `GET /v1/block/{blockHash}` — fetches metadata for a Bitcoin block by its hash.
struct GetBlockRequest: Requestable {

    typealias Response = BlockResponse

    /// Block hash to look up (64-character hex string).
    let blockHash: String

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/v1/block/\(blockHash)" }
    var method: HTTPMethod { .get }
}
