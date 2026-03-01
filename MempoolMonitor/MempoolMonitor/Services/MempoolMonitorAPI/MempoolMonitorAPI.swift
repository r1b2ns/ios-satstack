import Foundation

/// Access layer for the Mempool Monitor server API.
///
/// The host is read at runtime from the `MempoolMonitorHost` key in `Info.plist`,
/// which is populated by the `MEMPOOL_MONITOR_HOST` variable in `Local.xcconfig`.
///
/// Encapsulates all available endpoints and uses `NetworkManager` internally,
/// exposing high-level domain-oriented methods.
///
/// ```swift
/// try await MempoolMonitorAPI.shared.watchTransaction(
///     txId: "abc123…",
///     deviceToken: "deviceHex…",
///     activityToken: "activityHex…"
/// )
/// ```
final class MempoolMonitorAPI: MempoolMonitorAPIProtocol {

    // MARK: - Shared

    static let shared = MempoolMonitorAPI()

    // MARK: - Dependencies

    let baseURL: URL
    private let network: any NetworkProtocol

    // MARK: - Init

    init(
        baseURL: URL = MempoolMonitorAPI.resolvedBaseURL(),
        network: any NetworkProtocol = NetworkManager.shared
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    // MARK: - Private helpers

    /// Reads `MempoolMonitorHost` from Info.plist (injected by xcconfig) and builds the base URL.
    /// Falls back to `http://localhost:3000` if the key is absent.
    private static func resolvedBaseURL() -> URL {
        let host = Bundle.main.infoDictionary?["MempoolMonitorHost"] as? String
                   ?? "localhost:3000"
        return URL(string: "http://\(host)")!
    }

    // MARK: - Endpoints

    /// Registers a Bitcoin transaction for monitoring via push notification and Live Activity.
    ///
    /// - Parameters:
    ///   - txId:          Bitcoin transaction hash (64-character hex string).
    ///   - deviceToken:   APNs device token (hex).
    ///   - activityToken: Live Activity push token (hex). Omitted from the payload when `nil`.
    /// - Returns: The current transaction state from the server.
    @discardableResult
    func watchTransaction(
        txId: String,
        deviceToken: String,
        activityToken: String?
    ) async throws -> WatchTransactionResponse {
        try await network.perform(
            WatchTransactionRequest(
                baseURL:       baseURL,
                txId:          txId,
                deviceToken:   deviceToken,
                activityToken: activityToken
            )
        )
    }

    /// Fetches the current state of a monitored Bitcoin transaction.
    ///
    /// - Parameter txId: Bitcoin transaction hash (64-character hex string).
    /// - Returns: The current transaction state from the server.
    func fetchTransaction(txId: String) async throws -> WatchTransactionResponse {
        try await network.perform(
            GetTransactionRequest(baseURL: baseURL, txId: txId)
        )
    }
}
