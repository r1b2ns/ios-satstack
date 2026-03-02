import Foundation

/// Abstracts the capabilities of the Alternative.me API access layer.
///
/// Conform to this protocol to create alternative implementations,
/// such as mocks for unit testing.
///
/// ```swift
/// struct MockAlternativeMeAPI: AlternativeMeAPIProtocol {
///     func fetchFearAndGreedIndex() async throws -> FearAndGreedIndexResponse { … }
/// }
/// ```
protocol AlternativeMeAPIProtocol {

    /// Fetches the latest Crypto Fear and Greed Index.
    ///
    /// - Returns: The current Fear and Greed Index data including score and classification.
    func fetchFearAndGreedIndex() async throws -> FearAndGreedIndexResponse
}
