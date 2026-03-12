import Foundation

/// Access layer for the mempool.space public API.
///
/// Provides Bitcoin network data — prices, difficulty adjustment, block info and
/// recommended fees — and uses `NetworkManager` internally, exposing high-level
/// domain-oriented methods.
///
/// ```swift
/// let fees = try await MempoolSpaceAPI.shared.fetchRecommendedFees()
/// let block = try await MempoolSpaceAPI.shared.fetchBlock(hash: "000000000019d6…")
/// ```
final class MempoolSpaceAPI: MempoolSpaceAPIProtocol {

    // MARK: - Shared

    static let shared = MempoolSpaceAPI()

    // MARK: - Dependencies

    private let network: any NetworkProtocol

    // MARK: - Init

    init(network: any NetworkProtocol = NetworkManager.shared) {
        self.network = network
    }

    // MARK: - Endpoints

    /// Fetches the current Bitcoin price in multiple fiat currencies.
    func fetchPrices() async throws -> PricesResponse {
        try await network.perform(GetPricesRequest())
    }

    /// Fetches Bitcoin mining difficulty adjustment statistics for the current epoch.
    func fetchDifficultyAdjustment() async throws -> DifficultyAdjustmentResponse {
        try await network.perform(GetDifficultyAdjustmentRequest())
    }

    /// Fetches metadata for a Bitcoin block by its hash.
    ///
    /// - Parameter hash: 64-character hex block hash.
    func fetchBlock(hash: String) async throws -> BlockResponse {
        try await network.perform(GetBlockRequest(blockHash: hash))
    }

    /// Fetches the current recommended Bitcoin transaction fee rates.
    func fetchRecommendedFees() async throws -> RecommendedFeesResponse {
        try await network.perform(GetRecommendedFeesRequest())
    }

    /// Fetches the current best block height (chain tip).
    func fetchBlockTipHeight() async throws -> Int {
        try await network.perform(GetBlockTipHeightRequest())
    }

    /// Fetches metadata and confirmation status for a Bitcoin transaction.
    ///
    /// - Parameter txId: 64-character hex transaction ID.
    func fetchTransaction(txId: String) async throws -> MempoolTransactionResponse {
        try await network.perform(GetMempoolTransactionRequest(txId: txId))
    }

    /// Fetches on-chain and mempool statistics for a Bitcoin address.
    ///
    /// - Parameter address: A Bitcoin address (bc1…, tb1…, 1…, 3…).
    func fetchAddressInfo(address: String) async throws -> AddressInfoResponse {
        try await network.perform(GetAddressInfoRequest(address: address))
    }

    /// Fetches the transaction history for a Bitcoin address.
    ///
    /// - Parameter address: A Bitcoin address (bc1…, tb1…, 1…, 3…).
    func fetchAddressTransactions(address: String) async throws -> [AddressTransactionResponse] {
        try await network.perform(GetAddressTransactionsRequest(address: address))
    }

    /// Fetches on-chain and mempool statistics for an extended public key.
    ///
    /// - Parameter xpub: An extended public key (xpub, ypub, zpub, etc.).
    func fetchXpubInfo(xpub: String) async throws -> XpubInfoResponse {
        try await network.perform(GetXpubInfoRequest(xpub: xpub))
    }

    /// Fetches the transaction history for all addresses derived from an extended public key.
    ///
    /// - Parameter xpub: An extended public key (xpub, ypub, zpub, etc.).
    func fetchXpubTransactions(xpub: String) async throws -> [AddressTransactionResponse] {
        try await network.perform(GetXpubTransactionsRequest(xpub: xpub))
    }
}
