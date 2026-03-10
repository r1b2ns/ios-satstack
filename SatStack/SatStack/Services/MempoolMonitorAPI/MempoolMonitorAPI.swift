import Foundation

/// Access layer for the Mempool Monitor server API.
///
/// The host and API key are read at runtime from `Info.plist` keys injected
/// by `MEMPOOL_MONITOR_HOST` and `MEMPOOL_MONITOR_HOST_API_KEY` in the xcconfig.
///
/// Every outgoing request carries an `X-API-Key` header when the key is non-empty.
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
    let apiKey: String
    private let network: any NetworkProtocol

    // MARK: - Init

    init(
        baseURL: URL    = MempoolMonitorAPI.resolvedBaseURL(),
        apiKey: String  = MempoolMonitorAPI.resolvedAPIKey(),
        network: any NetworkProtocol = NetworkManager.shared
    ) {
        self.baseURL = baseURL
        self.apiKey  = apiKey
        self.network = network
    }

    // MARK: - Private helpers

    /// Reads `MempoolMonitorScheme` and `MempoolMonitorHost` from Info.plist
    /// (injected by xcconfig) and builds the base URL.
    /// Falls back to `http://localhost:3000` if the keys are absent.
    private static func resolvedBaseURL() -> URL {
        let scheme = Bundle.main.infoDictionary?["MempoolMonitorScheme"] as? String ?? "http"
        let host   = Bundle.main.infoDictionary?["MempoolMonitorHost"]   as? String ?? "localhost:3000"
        return URL(string: "\(scheme)://\(host)")!
    }

    /// Reads `MempoolMonitorHostApiKey` from Info.plist (injected by xcconfig).
    /// Returns an empty string when the key is absent or blank.
    private static func resolvedAPIKey() -> String {
        Bundle.main.infoDictionary?["MempoolMonitorHostApiKey"] as? String ?? ""
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
                apiKey:        apiKey,
                txId:          txId,
                deviceToken:   deviceToken,
                activityToken: activityToken
            )
        )
    }

}
