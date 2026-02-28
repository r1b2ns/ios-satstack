import Foundation

/// Abstracts the HTTP request execution capabilities.
///
/// Conform to this protocol to create alternative implementations of `NetworkManager`,
/// such as mocks for unit testing.
///
/// ```swift
/// struct MockNetworkManager: NetworkProtocol {
///     func perform<R: Requestable>(_ requestable: R) async throws -> R.Response { … }
/// }
/// ```
protocol NetworkProtocol {

    /// Executes `requestable`, validates the status code, and returns the decoded response.
    ///
    /// - Throws: `HTTPError` on network failure, HTTP error status code, or decoding failure.
    func perform<R: Requestable>(_ requestable: R) async throws -> R.Response
}
