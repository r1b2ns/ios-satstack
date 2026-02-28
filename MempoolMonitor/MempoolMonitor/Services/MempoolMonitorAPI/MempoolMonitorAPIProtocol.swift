import Foundation

/// Abstracts the capabilities of the Mempool Monitor API access layer.
///
/// Conform to this protocol to create alternative implementations of `MempoolMonitorAPI`,
/// such as mocks for unit testing.
///
/// ```swift
/// struct MockMempoolMonitorAPI: MempoolMonitorAPIProtocol {
///     func watchTransaction(txId: String, deviceToken: String, activityToken: String?) async throws { … }
/// }
/// ```
protocol MempoolMonitorAPIProtocol {

    /// Registers a Bitcoin transaction for monitoring via push notification and Live Activity.
    ///
    /// - Parameters:
    ///   - txId:          Bitcoin transaction hash (64-character hex string).
    ///   - deviceToken:   APNs device token (hex).
    ///   - activityToken: Live Activity push token (hex). Omitted from the payload when `nil`.
    func watchTransaction(
        txId: String,
        deviceToken: String,
        activityToken: String?
    ) async throws
}
