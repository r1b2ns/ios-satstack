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

    /// Fetches metadata and confirmation status for a Bitcoin transaction.
    ///
    /// - Parameter txId: 64-character hex transaction ID.
    func fetchTransaction(txId: String) async throws -> MempoolTransactionResponse
}
