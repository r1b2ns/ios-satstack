import Foundation

// MARK: - Response

/// Top-level response for `GET /xpub/{xpub}`.
///
/// Contains on-chain and mempool statistics for an extended public key.
struct XpubInfoResponse: Decodable {

    /// The queried extended public key.
    let pubkey: String

    /// Confirmed (on-chain) statistics.
    let chainStats: XpubStats

    /// Unconfirmed (mempool) statistics.
    let mempoolStats: XpubStats

    enum CodingKeys: String, CodingKey {
        case pubkey
        case chainStats   = "chain_stats"
        case mempoolStats = "mempool_stats"
    }
}

/// Funding and spending statistics for an extended public key.
struct XpubStats: Decodable {

    /// Number of outputs funding addresses derived from this xpub.
    let fundedTxoCount: Int

    /// Total value in satoshis received by all derived addresses.
    let fundedTxoSum: Int64

    /// Number of outputs spent from addresses derived from this xpub.
    let spentTxoCount: Int

    /// Total value in satoshis spent from all derived addresses.
    let spentTxoSum: Int64

    /// Total number of transactions involving this xpub.
    let txCount: Int

    enum CodingKeys: String, CodingKey {
        case fundedTxoCount = "funded_txo_count"
        case fundedTxoSum   = "funded_txo_sum"
        case spentTxoCount  = "spent_txo_count"
        case spentTxoSum    = "spent_txo_sum"
        case txCount        = "tx_count"
    }
}

// MARK: - Requests

/// `GET /xpub/{xpub}` — fetches on-chain and mempool statistics for an extended public key.
struct GetXpubInfoRequest: Requestable {

    typealias Response = XpubInfoResponse

    /// The extended public key to look up.
    let xpub: String

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/xpub/\(xpub)" }
    var method: HTTPMethod { .get }
}

/// `GET /xpub/{xpub}/txs` — fetches the transaction history for an extended public key.
///
/// Returns the same `AddressTransactionResponse` schema as the address transaction endpoint.
struct GetXpubTransactionsRequest: Requestable {

    typealias Response = [AddressTransactionResponse]

    /// The extended public key to look up.
    let xpub: String

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/xpub/\(xpub)/txs" }
    var method: HTTPMethod { .get }
}
