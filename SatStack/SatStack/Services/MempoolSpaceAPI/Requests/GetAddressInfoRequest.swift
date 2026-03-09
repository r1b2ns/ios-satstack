import Foundation

// MARK: - Response

/// Top-level response for `GET /address/{address}`.
///
/// Contains on-chain and mempool statistics for a single Bitcoin address.
struct AddressInfoResponse: Decodable {

    /// The queried Bitcoin address.
    let address: String

    /// Confirmed (on-chain) statistics.
    let chainStats: AddressStats

    /// Unconfirmed (mempool) statistics.
    let mempoolStats: AddressStats

    enum CodingKeys: String, CodingKey {
        case address
        case chainStats  = "chain_stats"
        case mempoolStats = "mempool_stats"
    }
}

/// Funding and spending statistics for an address.
struct AddressStats: Decodable {

    /// Number of outputs funding this address.
    let fundedTxoCount: Int

    /// Total value in satoshis received by this address.
    let fundedTxoSum: Int64

    /// Number of outputs spent from this address.
    let spentTxoCount: Int

    /// Total value in satoshis spent from this address.
    let spentTxoSum: Int64

    /// Total number of transactions involving this address.
    let txCount: Int

    enum CodingKeys: String, CodingKey {
        case fundedTxoCount = "funded_txo_count"
        case fundedTxoSum   = "funded_txo_sum"
        case spentTxoCount  = "spent_txo_count"
        case spentTxoSum    = "spent_txo_sum"
        case txCount        = "tx_count"
    }
}

// MARK: - Request

/// `GET /address/{address}` — fetches on-chain and mempool statistics for a Bitcoin address.
struct GetAddressInfoRequest: Requestable {

    typealias Response = AddressInfoResponse

    /// The Bitcoin address to look up.
    let address: String

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/address/\(address)" }
    var method: HTTPMethod { .get }
}
