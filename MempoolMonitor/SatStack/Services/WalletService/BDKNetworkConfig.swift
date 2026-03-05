import BitcoinDevKit
import Foundation

/// Centralised BDK network configuration.
///
/// In **DEBUG** builds the app connects to the Bitcoin **Signet** test network,
/// keeping development wallets from touching real funds.
/// In **Release** builds it connects to Bitcoin **Mainnet**.
enum BDKNetworkConfig {

    /// The BDK network used for wallet creation, descriptor derivation, and sync.
    static let network: Network = {
        #if DEBUG
        return .signet
        #else
        return .bitcoin
        #endif
    }()

    /// Esplora (HTTP REST) base URL for the active network.
    static let esploraURL: String = {
        switch BDKNetworkConfig.network {
        case .bitcoin:
            return "https://mempool.space/api"
            
        default:
            return "https://mempool.space/signet/api"
        }
    }()

    /// Electrum (TCP) server URL for the active network.
    static let electrumURL: String = {
        
        switch BDKNetworkConfig.network {
        case .bitcoin:
            return "ssl://electrum.blockstream.info:50002"
            
        default:
            return "ssl://mempool.space:60602"
        }
    }()

    /// Human-readable name for log messages.
    static var networkName: String {
        network == .bitcoin ? "mainnet" : "signet"
    }

    /// Mempool.space base URL for viewing transactions on the active network.
    static let mempoolExplorerURL: String = {
        switch BDKNetworkConfig.network {
        case .bitcoin:
            return "https://mempool.space"

        default:
            return "https://mempool.space/signet"
        }
    }()

    /// Returns the full mempool.space URL for a given transaction ID.
    static func transactionURL(txid: String) -> URL? {
        URL(string: "\(mempoolExplorerURL)/tx/\(txid)")
    }
}
