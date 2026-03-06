import BitcoinDevKit

/// BDK script inspector used during the first full wallet scan.
///
/// Conforms to `FullScanScriptInspector` so BDK can call `inspect` for every
/// script it derives from the wallet's keychains. Because a full scan has no
/// known upper-bound, progress is expressed as a monotonically-increasing count
/// of scripts inspected rather than a fraction.
///
/// Usage:
/// ```swift
/// let inspector = WalletFullScanScriptInspector(walletId: wallet.id) { count in
///     Log.print.info("[FullScan] \(count) scripts inspected")
/// }
/// let request = try wallet.startFullScan()
///     .inspectSpksForAllKeychains(inspector: inspector)
/// ```
actor WalletFullScanScriptInspector: @preconcurrency FullScanScriptInspector {

    private let updateProgress: @Sendable (UInt64) -> Void
    private var inspectedCount: UInt64 = 0

    init(updateProgress: @escaping @Sendable (UInt64) -> Void) {
        self.updateProgress = updateProgress
    }

    // MARK: - FullScanScriptInspector

    func inspect(keychain: KeychainKind, index: UInt32, script: Script) {
        inspectedCount += 1
        updateProgress(inspectedCount)
    }
}
