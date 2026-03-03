import BitcoinDevKit
import Foundation

/// Production implementation of `WalletServiceProtocol` backed by the Bitcoin Dev Kit.
///
/// ### Sync strategy
/// Every wallet starts life needing a **full scan** — BDK walks every derived
/// script pubkey until it finds a gap of `stopGap` addresses with no history.
/// Once that full scan succeeds the fact is persisted in `UserDefaults`.
/// All subsequent refreshes use an **incremental sync** (`startSyncWithRevealedSpks`)
/// which only checks the scripts already revealed by the keychain, making it
/// much faster.
///
/// ### Progress reporting
/// Both paths attach a script inspector that logs progress to the console via
/// `Log.print` — `WalletFullScanScriptInspector` for full scans and
/// `WalletSyncScriptInspector` for incremental syncs.
struct BDKWalletService: WalletServiceProtocol {

    /// Esplora endpoint used for all wallet synchronisation.
    private static let esploraUrl = "https://mempool.space/api"

    // MARK: - createNewWallet

    func createNewWallet() async throws -> WalletCreationResult {
        let mnemonic = Mnemonic(wordCount: .words12)
        let phrase = mnemonic.description
        let words = phrase.components(separatedBy: " ")
        let walletId = UUID()

        let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: .bitcoin)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: .bitcoin)

        let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
        _ = try BitcoinDevKit.Wallet(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            network: .bitcoin,
            persister: persister
        )

        let wallet = Wallet(id: walletId, name: "My Wallet", theme: .bitcoin, balanceBTC: 0.0, mnemonicPhrase: phrase)
        let backup = WalletBackup(walletId: walletId, kind: .seedPhrase(words))
        return WalletCreationResult(wallet: wallet, backup: backup)
    }

    // MARK: - importWallet

    func importWallet(from source: WalletImportSource) async throws -> Wallet {
        switch source {
        case .seedPhrase(let words):
            let phrase = words.joined(separator: " ")
            let mnemonic = try Mnemonic.fromString(mnemonic: phrase)
            let walletId = UUID()

            let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
            let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: .bitcoin)
            let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: .bitcoin)

            let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
            _ = try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: .bitcoin,
                persister: persister
            )
            return Wallet(id: walletId, name: "Imported Wallet", theme: .bitcoin, balanceBTC: 0.0, mnemonicPhrase: phrase)

        case .address(let address):
            guard address.hasPrefix("bc1") || address.hasPrefix("1") || address.hasPrefix("3") else {
                throw WalletServiceError.invalidImportSource("'\(address)' does not look like a valid Bitcoin address.")
            }
            return Wallet(id: UUID(), name: "Watch-only Address", theme: .watchOnly, balanceBTC: 0.0)

        case .xpub(let key):
            guard key.hasPrefix("xpub") || key.hasPrefix("ypub") || key.hasPrefix("zpub") else {
                throw WalletServiceError.invalidImportSource("'\(key.prefix(8))…' is not a recognised extended public key prefix.")
            }
            return Wallet(id: UUID(), name: "Watch-only xpub", theme: .watchOnly, balanceBTC: 0.0)

        case .privateKey:
            throw WalletServiceError.invalidImportSource("Private key import is not yet supported.")
        }
    }

    // MARK: - fetchWalletBalance

    /// Synchronises the wallet (full scan or incremental) and returns the total balance in satoshis.
    func fetchWalletBalance(for wallet: Wallet) async throws -> UInt64 {
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id)
        return bdkWallet.balance().total.toSat()
    }

    // MARK: - fetchWalletTransactions

    /// Synchronises the wallet (full scan or incremental) and returns the transaction
    /// history sorted newest-first with net BTC values (positive = received, negative = sent).
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id)

        return bdkWallet.transactions()
            .map { canonical -> WalletTransaction in
                let tx = canonical.transaction
                let txid = tx.computeTxid().description

                let sentReceived = bdkWallet.sentAndReceived(tx: tx)
                let netSats = Int64(sentReceived.received.toSat()) - Int64(sentReceived.sent.toSat())
                let valueBTC = Double(netSats) / 100_000_000.0

                let date: Date
                switch canonical.chainPosition {
                case .confirmed(let blockTime, _):
                    date = Date(timeIntervalSince1970: TimeInterval(blockTime.confirmationTime))
                case .unconfirmed:
                    date = .now
                }

                return WalletTransaction(id: UUID(), address: txid, valueBTC: valueBTC, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - fetchWalletBackup

    func fetchWalletBackup(for wallet: Wallet) async throws -> WalletBackup {
        guard let phrase = wallet.mnemonicPhrase else {
            throw WalletServiceError.backupUnavailable
        }
        let words = phrase.components(separatedBy: " ")
        return WalletBackup(walletId: wallet.id, kind: .seedPhrase(words))
    }
}

// MARK: - Private sync logic

private extension BDKWalletService {

    /// Decides whether to run a full scan or an incremental sync, executes it,
    /// and marks the full scan as completed in `UserDefaults` on success.
    func syncOrFullScan(_ bdkWallet: BitcoinDevKit.Wallet, persister: Persister, walletId: UUID) throws {
        if Self.needsFullScan(for: walletId) {
            Log.print.info("[BDK] Starting full scan for wallet \(walletId.uuidString)")
            try performFullScan(bdkWallet, persister: persister, walletId: walletId)
            Self.markFullScanCompleted(for: walletId)
        } else {
            Log.print.info("[BDK] Starting incremental sync for wallet \(walletId.uuidString)")
            try performSync(bdkWallet, persister: persister, walletId: walletId)
        }
    }

    /// Runs a full BIP-84 wallet scan via the Esplora backend, reporting
    /// per-script progress to the console through `WalletFullScanScriptInspector`.
    /// Explicitly persists the update to SQLite so subsequent loads reflect the scan results.
    func performFullScan(_ bdkWallet: BitcoinDevKit.Wallet, persister: Persister, walletId: UUID) throws {
        let inspector = WalletFullScanScriptInspector { count in
            Log.print.info("[FullScan] Wallet \(walletId.uuidString): \(count) scripts inspected")
        }

        let client = EsploraClient(url: Self.esploraUrl)
        let request = try bdkWallet.startFullScan()
            .inspectSpksForAllKeychains(inspector: inspector)
            .build()
        let update = try client.fullScan(request: request, stopGap: 20, parallelRequests: 5)
        try bdkWallet.applyUpdate(update: update)
        _ = try bdkWallet.persist(persister: persister)
        Log.print.info("[FullScan] Wallet \(walletId.uuidString): full scan completed and persisted.")
    }

    /// Runs an incremental sync against the Esplora backend using only the
    /// already-revealed script pubkeys, reporting progress through `WalletSyncScriptInspector`.
    /// Explicitly persists the update to SQLite so subsequent loads reflect the sync results.
    func performSync(_ bdkWallet: BitcoinDevKit.Wallet, persister: Persister, walletId: UUID) throws {
        let inspector = WalletSyncScriptInspector { inspected, total in
            Log.print.info("[Sync] Wallet \(walletId.uuidString): \(inspected)/\(total) scripts checked")
        }

        let client = EsploraClient(url: Self.esploraUrl)
        let request = try bdkWallet.startSyncWithRevealedSpks()
            .inspectSpks(inspector: inspector)
            .build()
        let update = try client.sync(request: request, parallelRequests: 5)
        try bdkWallet.applyUpdate(update: update)
        _ = try bdkWallet.persist(persister: persister)
        Log.print.info("[Sync] Wallet \(walletId.uuidString): incremental sync completed and persisted.")
    }

    /// Loads (or creates) the on-disk BDK wallet for the given app `Wallet`.
    /// Returns both the wallet and its persister so callers can flush updates to SQLite.
    func loadBDKWallet(for wallet: Wallet) throws -> (BitcoinDevKit.Wallet, Persister) {
        guard let phrase = wallet.mnemonicPhrase else {
            throw WalletServiceError.unknown("No mnemonic available for this wallet.")
        }
        let mnemonic = try Mnemonic.fromString(mnemonic: phrase)
        let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: .bitcoin)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: .bitcoin)

        let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: wallet.id))
        do {
            let bdkWallet = try BitcoinDevKit.Wallet.load(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                persister: persister
            )
            return (bdkWallet, persister)
        } catch {
            let bdkWallet = try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: .bitcoin,
                persister: persister
            )
            return (bdkWallet, persister)
        }
    }

    // MARK: - Full-scan state (UserDefaults)

    /// Returns `true` when the wallet has never completed a full scan.
    /// Defaults to `true` for wallets not yet tracked in `UserDefaults`.
    static func needsFullScan(for walletId: UUID) -> Bool {
        !UserDefaults.standard.bool(forKey: "bdk_full_scan_\(walletId.uuidString)")
    }

    /// Persists the fact that the given wallet has completed its initial full scan.
    static func markFullScanCompleted(for walletId: UUID) {
        UserDefaults.standard.set(true, forKey: "bdk_full_scan_\(walletId.uuidString)")
        Log.print.info("[BDK] Full scan state saved for wallet \(walletId.uuidString)")
    }

    /// Returns the SQLite database path for the given wallet UUID.
    static func walletDatabasePath(for id: UUID) -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("wallet_\(id.uuidString).sqlite").path
    }
}
