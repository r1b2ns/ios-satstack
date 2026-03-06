import Foundation

// MARK: - Response

/// A single transaction returned by `GET /address/{address}/txs`.
struct AddressTransactionResponse: Decodable {

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

    /// List of transaction inputs.
    let vin: [AddressTxVin]

    /// List of transaction outputs.
    let vout: [AddressTxVout]

    /// Confirmation status of the transaction.
    let status: AddressTxStatus
}

/// A single transaction input.
struct AddressTxVin: Decodable {

    /// The previous output being spent.
    let prevout: AddressTxVout?
}

/// A single transaction output.
struct AddressTxVout: Decodable {

    /// The destination script in ASM format.
    let scriptpubkeyAsm: String?

    /// The destination address, if applicable.
    let scriptpubkeyAddress: String?

    /// Output value in satoshis.
    let value: Int64

    enum CodingKeys: String, CodingKey {
        case scriptpubkeyAsm     = "scriptpubkey_asm"
        case scriptpubkeyAddress = "scriptpubkey_address"
        case value
    }
}

/// Confirmation details embedded in a transaction response.
struct AddressTxStatus: Decodable {

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

/// `GET /address/{address}/txs` — fetches the transaction history for a Bitcoin address.
struct GetAddressTransactionsRequest: Requestable {

    typealias Response = [AddressTransactionResponse]

    /// The Bitcoin address to look up.
    let address: String

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/address/\(address)/txs" }
    var method: HTTPMethod { .get }
}
