import Foundation

/// Access layer for the Alternative.me public API.
///
/// Provides the Crypto Fear and Greed Index and uses `NetworkManager` internally,
/// exposing high-level domain-oriented methods.
///
/// ```swift
/// let response = try await AlternativeMeAPI.shared.fetchFearAndGreedIndex()
/// ```
final class AlternativeMeAPI: AlternativeMeAPIProtocol {

    // MARK: - Shared

    static let shared = AlternativeMeAPI()

    // MARK: - Dependencies

    private let network: any NetworkProtocol

    // MARK: - Init

    init(network: any NetworkProtocol = NetworkManager.shared) {
        self.network = network
    }

    // MARK: - Endpoints

    /// Fetches the latest Crypto Fear and Greed Index.
    ///
    /// - Returns: The current Fear and Greed Index data including score and classification.
    func fetchFearAndGreedIndex() async throws -> FearAndGreedIndexResponse {
        try await network.perform(GetFearAndGreedIndexRequest())
    }
}
