import Foundation

/// Abstracts the capabilities of the mempool.space API access layer.
///
/// Conform to this protocol to create alternative implementations,
/// such as mocks for unit testing.
///
/// ```swift
/// struct MockMempoolSpaceAPI: MempoolSpaceAPIProtocol {
///     func fetchPrices() async throws -> PricesResponse { … }
///     func fetchDifficultyAdjustment() async throws -> DifficultyAdjustmentResponse { … }
///     func fetchBlock(hash: String) async throws -> BlockResponse { … }
///     func fetchRecommendedFees() async throws -> RecommendedFeesResponse { … }
///     func fetchTransaction(txId: String) async throws -> MempoolTransactionResponse { … }
/// }
/// ```
protocol MempoolSpaceAPIProtocol {

    /// Fetches the current Bitcoin price in multiple fiat currencies.
    func fetchPrices() async throws -> PricesResponse

    /// Fetches Bitcoin mining difficulty adjustment statistics for the current epoch.
    func fetchDifficultyAdjustment() async throws -> DifficultyAdjustmentResponse

    /// Fetches metadata for a Bitcoin block by its hash.
    ///
    /// - Parameter hash: 64-character hex block hash.
    func fetchBlock(hash: String) async throws -> BlockResponse

    /// Fetches the current recommended Bitcoin transaction fee rates.
    func fetchRecommendedFees() async throws -> RecommendedFeesResponse

    /// Fetches the current best block height (chain tip).
    func fetchBlockTipHeight() async throws -> Int

    /// Fetches metadata and confirmation status for a Bitcoin transaction.
    ///
    /// - Parameter txId: 64-character hex transaction ID.
    func fetchTransaction(txId: String) async throws -> MempoolTransactionResponse

    /// Fetches on-chain and mempool statistics for a Bitcoin address.
    ///
    /// - Parameter address: A Bitcoin address (bc1…, tb1…, 1…, 3…).
    func fetchAddressInfo(address: String) async throws -> AddressInfoResponse

    /// Fetches the transaction history for a Bitcoin address.
    ///
    /// - Parameter address: A Bitcoin address (bc1…, tb1…, 1…, 3…).
    func fetchAddressTransactions(address: String) async throws -> [AddressTransactionResponse]

    /// Fetches on-chain and mempool statistics for an extended public key.
    ///
    /// - Parameter xpub: An extended public key (xpub, ypub, zpub, etc.).
    func fetchXpubInfo(xpub: String) async throws -> XpubInfoResponse

    /// Fetches the transaction history for all addresses derived from an extended public key.
    ///
    /// - Parameter xpub: An extended public key (xpub, ypub, zpub, etc.).
    func fetchXpubTransactions(xpub: String) async throws -> [AddressTransactionResponse]
}
