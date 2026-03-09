import BitcoinDevKit
import Foundation

/// Centralised BDK network configuration.
///
/// All values are read from `Info.plist` build settings injected via xcconfig files:
/// - **Debug.xcconfig** → Signet (test network)
/// - **Release.xcconfig** → Mainnet (production)
///
/// See `Configs/Debug.xcconfig` and `Configs/Release.xcconfig` for the raw values.
enum BDKNetworkConfig {

    // MARK: - Info.plist helpers

    private static func infoPlistValue(for key: String) -> String? {
        Bundle.main.infoDictionary?[key] as? String
    }

    // MARK: - Network

    /// The BDK network used for wallet creation, descriptor derivation, and sync.
    static let network: Network = {
        guard let value = infoPlistValue(for: "BDKNetwork") else {
            Log.print.warning("[BDKNetworkConfig] BDKNetwork not found in Info.plist, defaulting to signet.")
            return .signet
        }
        switch value.lowercased() {
        case "bitcoin", "mainnet":
            return .bitcoin
        default:
            return .signet
        }
    }()

    /// Human-readable name for log messages.
    static var networkName: String {
        network == .bitcoin ? "mainnet" : "signet"
    }

    // MARK: - URLs

    /// Mempool.space base host/path (without scheme) for the active network.
    private static let mempoolBase: String = {
        infoPlistValue(for: "BDKMempoolBase")
            ?? (network == .bitcoin ? "mempool.space" : "mempool.space/signet")
    }()

    /// Esplora (HTTP REST) base URL for the active network.
    static let esploraURL: String = "https://\(mempoolBase)/api"

    /// Electrum (TCP/SSL) server URL for the active network.
    static let electrumURL: String = {
        guard let host = infoPlistValue(for: "BDKElectrumHost") else {
            return network == .bitcoin
                ? "ssl://electrum.blockstream.info:50002"
                : "ssl://mempool.space:60602"
        }
        return "ssl://\(host)"
    }()

    /// Mempool.space base URL for viewing transactions on the active network.
    static let mempoolExplorerURL: String = "https://\(mempoolBase)"

    /// Returns the full mempool.space URL for a given transaction ID.
    static func transactionURL(txid: String) -> URL? {
        URL(string: "\(mempoolExplorerURL)/tx/\(txid)")
    }

    // MARK: - Donation

    /// Bitcoin donation address injected from xcconfig via Info.plist.
    static let bitcoinAddress: String = infoPlistValue(for: "BitcoinAddress") ?? ""
}
