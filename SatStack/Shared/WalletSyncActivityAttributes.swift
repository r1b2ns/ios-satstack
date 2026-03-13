import ActivityKit
import Foundation

// MARK: - Attributes

/// ActivityKit attributes for the wallet sync Live Activity.
///
/// Shared between the main app target (which starts/updates the activity)
/// and the widget extension (which renders the UI).
struct WalletSyncActivityAttributes: ActivityAttributes {

    // MARK: - Dynamic State

    struct ContentState: Codable, Hashable {

        /// Current phase of the sync session.
        var status: WalletSyncActivityStatus

        /// Incremental sync progress (0.0–1.0). Nil when indeterminate.
        var progress: Double?

        /// Number of scripts inspected so far during a full scan.
        var fullScanScriptCount: UInt64?

        /// Display name of the wallet currently being synced.
        var currentWalletName: String?

        /// Number of wallets that have finished syncing in this batch.
        var completedWallets: Int

        /// Total number of wallets in this sync batch.
        var totalWallets: Int

        /// Error description when `status == .failed`.
        var errorMessage: String?

        /// True when the app was suspended and is waiting for the system
        /// to resume execution via a background task.
        var isWaitingBackground: Bool = false

        /// True when the sync is running in Kyoto (CBF) mode.
        var isKyotoMode: Bool = false
    }

    // MARK: - Static Data

    /// Timestamp when the sync batch started.
    var startedAt: Date
}

// MARK: - Status

/// Describes the current phase of a wallet sync Live Activity.
enum WalletSyncActivityStatus: String, Codable, Hashable {
    case syncing
    case fullScanning
    case completed
    case failed
}
