import Foundation
@testable import MempoolMonitor

/// Fake implementation of `NetworkProtocol` for `MempoolMonitorAPI` tests.
///
/// Captures the `URLRequest` built by `Requestable` and allows simulating
/// errors without a real network.
final class MockNetworkManager: NetworkProtocol {

    // MARK: - Configuration

    /// Error to be thrown on the next call to `perform`. `nil` → success.
    var stubbedError: Error?

    // MARK: - Capture

    /// List of `URLRequest`s built, in the order they were performed.
    private(set) var capturedRequests: [URLRequest] = []

    /// Number of calls to `perform`.
    var callCount: Int { capturedRequests.count }

    // MARK: - NetworkProtocol

    func perform<R: Requestable>(_ requestable: R) async throws -> R.Response {
        // Captures the URLRequest built by Requestable for inspection in tests
        capturedRequests.append(try requestable.urlRequest())

        if let error = stubbedError { throw error }

        // Returns EmptyResponse (or any empty Decodable) as default response
        return try JSONDecoder().decode(R.Response.self, from: Data("{}".utf8))
    }
}
