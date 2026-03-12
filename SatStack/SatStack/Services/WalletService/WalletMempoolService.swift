import Foundation

// MARK: - WalletMempoolService

/// `WalletServiceProtocol` implementation backed by the mempool.space xpub REST API.
///
/// ### Balance
/// Fetched from `GET /xpub/{xpub}` — returns accurate totals for both confirmed
/// (chain_stats) and unconfirmed (mempool_stats) UTXOs in a single request.
///
/// ### Transactions
/// Fetched from `GET /xpub/{xpub}/txs` — returns the full transaction history across
/// all addresses derived from the xpub. Per-transaction net BTC values are set to
/// `0.0` because the API does not annotate outputs with their derived addresses,
/// making it impossible to compute a wallet-relative signed net without fetching each
/// derived address separately.
///
/// ### Address wallets
/// Single-address watch-only wallets do not have an xpub. These wallets are delegated
/// to `BDKWalletService.syncAddressWallet` which uses the mempool.space address API.
///
/// ### Unsupported operations
/// Lifecycle methods (`createNewWallet`, `importWallet`, `getReceiveAddress`,
/// `broadcastTransaction`, `fetchWalletBackup`) are delegated to `BDKWalletService`.
struct WalletMempoolService: WalletServiceProtocol {

    private let api: MempoolSpaceAPIProtocol
    private let bdkService: BDKWalletService

    init(
        api: MempoolSpaceAPIProtocol = MempoolSpaceAPI.shared,
        bdkService: BDKWalletService = BDKWalletService()
    ) {
        self.api = api
        self.bdkService = bdkService
    }

    // MARK: - fetchWalletBalance

    func fetchWalletBalance(for wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> UInt64 {
        onProgress(nil)
        let (balance, _) = try await syncXpubWallet(wallet)
        onProgress(1.0)
        return balance
    }

    // MARK: - fetchWalletTransactions

    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        let (_, transactions) = try await syncXpubWallet(wallet)
        return transactions
    }

    // MARK: - syncWallet

    func syncWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        onProgress(nil)
        let result = try await syncXpubWallet(wallet)
        onProgress(1.0)
        return result
    }

    // MARK: - fullScanWallet

    /// Mempool xpub API always returns the complete wallet history —
    /// there is no incremental vs. full scan distinction.
    func fullScanWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        try await syncWallet(wallet, onProgress: onProgress)
    }

    // MARK: - Delegated lifecycle operations

    func createNewWallet() async throws -> WalletCreationResult {
        try await bdkService.createNewWallet()
    }

    func importWallet(from source: WalletImportSource) async throws -> Wallet {
        try await bdkService.importWallet(from: source)
    }

    func getReceiveAddress(for wallet: Wallet) async throws -> String {
        try await bdkService.getReceiveAddress(for: wallet)
    }

    func broadcastTransaction(from wallet: Wallet, to address: String, amountSats: UInt64, feeRateSatVB: UInt64) async throws -> String {
        try await bdkService.broadcastTransaction(from: wallet, to: address, amountSats: amountSats, feeRateSatVB: feeRateSatVB)
    }

    func fetchWalletBackup(for wallet: Wallet) async throws -> WalletBackup {
        try await bdkService.fetchWalletBackup(for: wallet)
    }
}

// MARK: - Private sync logic

private extension WalletMempoolService {

    /// Resolves the sync strategy based on wallet type and delegates to the
    /// appropriate API path.
    ///
    /// - Address wallets: delegated to `bdkService.syncWallet` which already uses the
    ///   mempool.space address endpoint internally.
    /// - xpub / seed wallets with a populated `xpub`: use the xpub endpoint.
    /// - All other cases: throw `WalletServiceError.unknown`.
    func syncXpubWallet(_ wallet: Wallet) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        // Address wallets — BDKWalletService.syncWallet already delegates to the
        // mempool.space address API for address-only wallets.
        if wallet.isAddressWallet {
            return try await bdkService.syncWallet(wallet, onProgress: { _ in })
        }

        // xpub / seed wallets — require a populated xpub.
        guard let xpub = wallet.xpub, !xpub.isEmpty else {
            throw WalletServiceError.unknown(
                "No xpub available for wallet '\(wallet.name)'. " +
                "Re-import the wallet to generate a compatible xpub."
            )
        }

        async let infoTask = api.fetchXpubInfo(xpub: xpub)
        async let txsTask  = api.fetchXpubTransactions(xpub: xpub)

        let info   = try await infoTask
        let apiTxs = try await txsTask

        // Balance = funded − spent (chain + mempool).
        let chainBalance   = info.chainStats.fundedTxoSum   - info.chainStats.spentTxoSum
        let mempoolBalance = info.mempoolStats.fundedTxoSum - info.mempoolStats.spentTxoSum
        let totalSats = UInt64(max(0, chainBalance + mempoolBalance))

        // Map API transactions to the app's WalletTransaction model.
        // Per-transaction net BTC is set to 0.0 because the API does not
        // annotate outputs with their xpub-derived address, making a
        // wallet-relative signed net impossible without extra address lookups.
        let transactions: [WalletTransaction] = apiTxs.map { tx in
            let date: Date
            if let blockTime = tx.status.blockTime {
                date = Date(timeIntervalSince1970: TimeInterval(blockTime))
            } else {
                date = .now
            }

            return WalletTransaction(
                id: UUID(),
                address: tx.txid,
                valueBTC: 0.0,
                date: date,
                isConfirmed: tx.status.confirmed
            )
        }
        .sorted { $0.date > $1.date }

        Log.print.info("[Mempool xpub] \(wallet.name): balance = \(totalSats) sats, \(transactions.count) txs")
        return (totalSats, transactions)
    }
}
