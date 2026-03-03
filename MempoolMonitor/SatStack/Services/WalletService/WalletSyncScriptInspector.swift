import BitcoinDevKit
import Foundation

/// BDK script inspector used during incremental wallet syncs.
///
/// Conforms to `SyncScriptInspector` so BDK can call `inspect` for every
/// revealed script it checks against the blockchain. Unlike `WalletFullScanScriptInspector`,
/// incremental syncs know the total number of scripts in advance, so progress
/// is reported as `(inspected, total)` — suitable for a progress-bar style UI.
///
/// A throttling mechanism adds small delays for wallets with few scripts so that
/// progress callbacks are visible to the user rather than blinking past instantly.
///
/// Usage:
/// ```swift
/// let inspector = WalletSyncScriptInspector(walletId: wallet.id) { inspected, total in
///     Log.print.info("[Sync] \(inspected)/\(total) scripts checked")
/// }
/// let request = try wallet.startSyncWithRevealedSpks()
///     .inspectSpks(inspector: inspector)
/// ```
actor WalletSyncScriptInspector: @preconcurrency SyncScriptInspector {

    private let updateProgress: @Sendable (UInt64, UInt64) -> Void
    private var inspectedCount: UInt64 = 0
    private var totalCount: UInt64 = 0

    init(updateProgress: @escaping @Sendable (UInt64, UInt64) -> Void) {
        self.updateProgress = updateProgress
    }

    // MARK: - SyncScriptInspector

    func inspect(script: Script, total: UInt64) {
        totalCount = total
        inspectedCount += 1

        // For wallets with very few scripts, add a small delay so that
        // progress callbacks are visible before the sync completes.
        let delay: TimeInterval
        if total <= 5 {
            delay = 0.2
        } else if total < 10 {
            delay = 0.15
        } else if total < 20 {
            delay = 0.1
        } else {
            delay = 0
        }

        if delay > 0 {
            let captured = (inspectedCount, totalCount)
            Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                updateProgress(captured.0, captured.1)
            }
        } else {
            updateProgress(inspectedCount, totalCount)
        }
    }
}
