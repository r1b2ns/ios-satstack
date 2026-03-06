import BitcoinDevKit
import CryptoKit
import Foundation

// MARK: - BlockchainBackend

/// The blockchain data source used by `BDKWalletService` for wallet synchronisation.
enum BlockchainBackend {

    /// HTTP-based Esplora API (e.g. mempool.space).
    case esplora

    /// TCP-based Electrum protocol server.
    case electrum
    
    var url: String {
        switch self {
        case .esplora:  return BDKNetworkConfig.esploraURL
        case .electrum: return BDKNetworkConfig.electrumURL
        }
    }
}

// MARK: - BDKWalletService

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
/// ### Backend
/// The sync backend is configurable via `BlockchainBackend` — either Esplora (HTTP)
/// or Electrum (TCP). Defaults to mempool.space Esplora.
///
/// ### Progress reporting
/// Both paths attach a script inspector that logs progress to the console via
/// `Log.print` — `WalletFullScanScriptInspector` for full scans and
/// `WalletSyncScriptInspector` for incremental syncs.
struct BDKWalletService: WalletServiceProtocol {

    /// The blockchain backend used for wallet synchronisation.
    let backend: BlockchainBackend

    init(backend: BlockchainBackend = .electrum) {
        self.backend = backend
    }

    // MARK: - createNewWallet

    func createNewWallet() async throws -> WalletCreationResult {
        let mnemonic = Mnemonic(wordCount: .words12)
        let phrase = mnemonic.description
        let words = phrase.components(separatedBy: " ")
        let walletId = UUID()

        let secretKey = DescriptorSecretKey(network: BDKNetworkConfig.network, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: BDKNetworkConfig.network)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: BDKNetworkConfig.network)

        let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
        let bdkWallet = try BitcoinDevKit.Wallet(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            network: BDKNetworkConfig.network,
            persister: persister
        )
        // Persist the initial wallet state so Wallet.load succeeds on next open.
        _ = try bdkWallet.persist(persister: persister)
        Log.print.info("[BDK] New wallet created and persisted: \(walletId.uuidString)")

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

            let secretKey = DescriptorSecretKey(network: BDKNetworkConfig.network, mnemonic: mnemonic, password: nil)
            let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: BDKNetworkConfig.network)
            let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: BDKNetworkConfig.network)

            let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
            let bdkWallet = try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: BDKNetworkConfig.network,
                persister: persister
            )
            // Persist the initial wallet state so Wallet.load succeeds on next open.
            _ = try bdkWallet.persist(persister: persister)
            Log.print.info("[BDK] Imported wallet created and persisted: \(walletId.uuidString)")

            return Wallet(id: walletId, name: "Imported Wallet", theme: .bitcoin, balanceBTC: 0.0, mnemonicPhrase: phrase)

        case .address(let address):
            let validPrefixes = ["bc1", "tb1", "1", "3"]
            guard validPrefixes.contains(where: { address.hasPrefix($0) }) else {
                throw WalletServiceError.invalidImportSource("'\(address)' does not look like a valid Bitcoin address.")
            }
            let walletId = UUID()
            // Address wallets use the `addr()` descriptor which does not support
            // BDK's `startFullScan()`. Mark the full scan as already completed so
            // `syncOrFullScan` always uses incremental sync for this wallet.
            Self.markFullScanCompleted(for: walletId)
            return Wallet(id: walletId, name: "Watch-only", theme: .watchOnly, balanceBTC: 0.0, descriptor: address)

        case .xpub(let key):
            let validPrefixes = ["xpub", "ypub", "zpub", "tpub", "upub", "vpub"]
            guard validPrefixes.contains(where: { key.hasPrefix($0) }) else {
                throw WalletServiceError.invalidImportSource("'\(key.prefix(8))…' is not a recognised extended public key prefix.")
            }
            return Wallet(id: UUID(), name: "Watch-only", theme: .watchOnly, balanceBTC: 0.0, descriptor: key)

        case .privateKey:
            throw WalletServiceError.invalidImportSource("Private key import is not yet supported.")
        }
    }

    // MARK: - fetchWalletBalance

    /// Synchronises the wallet (full scan or incremental) and returns the total balance in satoshis.
    /// Address wallets use the mempool.space REST API instead of BDK sync.
    func fetchWalletBalance(for wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> UInt64 {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            let result = try await Self.syncAddressWallet(address: address)
            return result.balance
        }
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id, onProgress: onProgress)
        return bdkWallet.balance().total.toSat()
    }

    // MARK: - fetchWalletTransactions

    /// Synchronises the wallet (full scan or incremental) and returns the transaction
    /// history sorted newest-first with net BTC values (positive = received, negative = sent).
    /// Address wallets use the mempool.space REST API instead of BDK sync.
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            let result = try await Self.syncAddressWallet(address: address)
            return result.transactions
        }
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id, onProgress: { _ in })
        return Self.extractTransactions(from: bdkWallet)
    }

    // MARK: - syncWallet

    /// Loads the BDK wallet, syncs **once**, and returns both the balance and the
    /// transaction list in a single pass — avoiding the redundant double-sync that
    /// happens when `fetchWalletBalance` and `fetchWalletTransactions` are called
    /// independently.
    /// Address wallets use the mempool.space REST API instead of BDK sync.
    func syncWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            return try await Self.syncAddressWallet(address: address)
        }
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id, onProgress: onProgress)
        let balance = bdkWallet.balance().total.toSat()
        let transactions = Self.extractTransactions(from: bdkWallet)
        return (balance, transactions)
    }

    // MARK: - fullScanWallet

    /// Resets the full-scan flag so that `syncOrFullScan` treats the wallet as
    /// never-scanned, then performs the sync (which will now be a full scan).
    /// Address wallets simply re-fetch from the mempool.space API.
    func fullScanWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            return try await Self.syncAddressWallet(address: address)
        }
        Self.resetFullScanFlag(for: wallet.id)
        return try await syncWallet(wallet, onProgress: onProgress)
    }

    // MARK: - getReceiveAddress

    func getReceiveAddress(for wallet: Wallet) async throws -> String {
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        let addressInfo = bdkWallet.revealNextAddress(keychain: .external)
        _ = try bdkWallet.persist(persister: persister)
        let address = addressInfo.address.description
        Log.print.info("[BDK] Receive address derived (index \(addressInfo.index)): \(address)")
        return address
    }

    // MARK: - broadcastTransaction

    func broadcastTransaction(
        from wallet: Wallet,
        to address: String,
        amountSats: UInt64,
        feeRateSatVB: UInt64
    ) async throws -> String {
        guard wallet.mnemonicPhrase != nil else {
            throw WalletServiceError.broadcastFailed("Watch-only wallets cannot sign transactions.")
        }

        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)

        // Parse the recipient address and build the transaction.
        let recipientAddress = try Address(address: address, network: BDKNetworkConfig.network)
        let script = recipientAddress.scriptPubkey()
        let amount = Amount.fromSat(satoshi: amountSats)
        let rate = try FeeRate.fromSatPerVb(satVb: feeRateSatVB)

        let psbt = try TxBuilder()
            .addRecipient(script: script, amount: amount)
            .feeRate(feeRate: rate)
            .finish(wallet: bdkWallet)

        // Sign the transaction.
        let signed = try bdkWallet.sign(psbt: psbt)
        guard signed else {
            throw WalletServiceError.broadcastFailed("Transaction signing failed — wallet may lack a private key.")
        }

        // Extract the final transaction and broadcast via Esplora (HTTP).
        // ElectrumClient does not expose a broadcast method in BDK Swift,
        // so we always use the Esplora endpoint for broadcasting.
        let tx = try psbt.extractTx()
        let txid = tx.computeTxid()

        let broadcastClient = EsploraClient(url: BDKNetworkConfig.esploraURL)
        try broadcastClient.broadcast(transaction: tx)

        // Persist the wallet state so the spent UTXOs are reflected.
        _ = try bdkWallet.persist(persister: persister)
        let txidString = txid.description
        Log.print.info("[BDK] Transaction broadcast successfully: \(txidString)")

        return txidString
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
    func syncOrFullScan(
        _ bdkWallet: BitcoinDevKit.Wallet,
        persister: Persister,
        walletId: UUID,
        onProgress: @escaping @Sendable (Double?) -> Void
    ) throws {
        if Self.needsFullScan(for: walletId) {
            Log.print.info("[BDK] Starting full scan for wallet \(walletId.uuidString)")
            try performFullScan(bdkWallet, persister: persister, walletId: walletId, onProgress: onProgress)
            Self.markFullScanCompleted(for: walletId)
        } else {
            Log.print.info("[BDK] Starting incremental sync for wallet \(walletId.uuidString)")
            try performSync(bdkWallet, persister: persister, walletId: walletId, onProgress: onProgress)
        }
    }

    /// Runs a full BIP-84 wallet scan via the configured backend, reporting
    /// per-script progress to the console through `WalletFullScanScriptInspector`.
    /// Full scans report indeterminate progress (`nil`) since the total is unknown.
    /// Explicitly persists the update to SQLite so subsequent loads reflect the scan results.
    func performFullScan(
        _ bdkWallet: BitcoinDevKit.Wallet,
        persister: Persister,
        walletId: UUID,
        onProgress: @escaping @Sendable (Double?) -> Void
    ) throws {
        let inspector = WalletFullScanScriptInspector { count in
            Log.print.info("[FullScan] Wallet \(walletId.uuidString): \(count) scripts inspected")
            onProgress(nil)
        }

        let request = try bdkWallet.startFullScan()
            .inspectSpksForAllKeychains(inspector: inspector)
            .build()

        let update: Update
        switch backend {
        case .esplora:
            let client = EsploraClient(url: backend.url)
            update = try client.fullScan(request: request, stopGap: 20, parallelRequests: 5)
        case .electrum:
            let client = try ElectrumClient(url: backend.url)
            update = try client.fullScan(request: request, stopGap: 20, batchSize: 5, fetchPrevTxouts: true)
        }

        try bdkWallet.applyUpdate(update: update)
        let persisted = try bdkWallet.persist(persister: persister)
        Log.print.info("[FullScan] Wallet \(walletId.uuidString): full scan completed. Persisted: \(persisted)")
    }

    /// Runs an incremental sync against the configured backend using only the
    /// already-revealed script pubkeys, reporting determinate progress (0.0–1.0)
    /// through `WalletSyncScriptInspector`.
    /// Explicitly persists the update to SQLite so subsequent loads reflect the sync results.
    func performSync(
        _ bdkWallet: BitcoinDevKit.Wallet,
        persister: Persister,
        walletId: UUID,
        onProgress: @escaping @Sendable (Double?) -> Void
    ) throws {
        let inspector = WalletSyncScriptInspector { inspected, total in
            Log.print.info("[Sync] Wallet \(walletId.uuidString): \(inspected)/\(total) scripts checked")
            let fraction = total > 0 ? Double(inspected) / Double(total) : 0.0
            onProgress(fraction)
        }

        let request = try bdkWallet.startSyncWithRevealedSpks()
            .inspectSpks(inspector: inspector)
            .build()

        let update: Update
        switch backend {
        case .esplora:
            let client = EsploraClient(url: backend.url)
            update = try client.sync(request: request, parallelRequests: 5)
        case .electrum:
            let client = try ElectrumClient(url: backend.url)
            update = try client.sync(request: request, batchSize: 5, fetchPrevTxouts: true)
        }

        try bdkWallet.applyUpdate(update: update)
        let persisted = try bdkWallet.persist(persister: persister)
        Log.print.info("[Sync] Wallet \(walletId.uuidString): incremental sync completed. Persisted: \(persisted)")
    }

    /// Identifies the wallet type (seed, xpub, or address) and delegates loading
    /// to the appropriate specialised method.
    ///
    /// - Seed wallets → `loadSeedWallet` (full HD with signing capability)
    /// - xpub/ypub/zpub/tpub/upub/vpub → `loadXpubWallet` (watch-only HD tracking)
    /// - Bitcoin address (bc1/tb1/1/3) → `loadAddressWallet` (single-address watch-only)
    func loadBDKWallet(for wallet: Wallet) throws -> (BitcoinDevKit.Wallet, Persister) {
        if wallet.mnemonicPhrase != nil {
            return try loadSeedWallet(for: wallet)
        }

        if let descriptor = wallet.descriptor {
            let xpubPrefixes = ["xpub", "ypub", "zpub", "tpub", "upub", "vpub"]
            let addressPrefixes = ["bc1", "tb1", "1", "3"]

            if xpubPrefixes.contains(where: { descriptor.hasPrefix($0) }) {
                return try loadXpubWallet(for: wallet, xpub: descriptor)
            }
            if addressPrefixes.contains(where: { descriptor.hasPrefix($0) }) {
                return try loadAddressWallet(for: wallet, address: descriptor)
            }
        }

        throw WalletServiceError.unknown("Unable to determine wallet type for \(wallet.id.uuidString).")
    }

    // MARK: - Seed wallet

    /// Loads (or creates) a full HD wallet from a BIP-39 mnemonic phrase.
    ///
    /// When `Wallet.load` fails (first run or corrupted database), a brand-new
    /// BDK wallet is created and its initial state is persisted immediately.
    func loadSeedWallet(for wallet: Wallet) throws -> (BitcoinDevKit.Wallet, Persister) {
        guard let phrase = wallet.mnemonicPhrase else {
            throw WalletServiceError.unknown("No mnemonic available for wallet \(wallet.id.uuidString).")
        }

        let mnemonic = try Mnemonic.fromString(mnemonic: phrase)
        let secretKey = DescriptorSecretKey(network: BDKNetworkConfig.network, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: BDKNetworkConfig.network)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: BDKNetworkConfig.network)

        return try loadOrCreateDualDescriptorWallet(
            walletId: wallet.id,
            externalDescriptor: externalDescriptor,
            internalDescriptor: internalDescriptor
        )
    }

    // MARK: - Xpub wallet

    /// Loads (or creates) a watch-only HD wallet from an extended public key.
    ///
    /// BDK's miniscript parser only understands standard BIP-32 encoding
    /// (`xpub` for mainnet, `tpub` for testnet/signet), so SLIP-0132 keys
    /// are converted to the standard form first.
    ///
    /// The descriptor type is selected based on the **original** prefix:
    /// - `zpub` / `vpub` → `wpkh()` — BIP-84 (native segwit)
    /// - `ypub` / `upub` → `sh(wpkh())` — BIP-49 (nested segwit)
    /// - `xpub` / `tpub` → `pkh()` — BIP-44 (legacy)
    func loadXpubWallet(for wallet: Wallet, xpub: String) throws -> (BitcoinDevKit.Wallet, Persister) {
        // Convert SLIP-0132 encoding to standard BIP-32 xpub/tpub for BDK compatibility.
        let standardKey = Self.convertToStandardKey(xpub)

        let externalDescriptor: Descriptor
        let internalDescriptor: Descriptor

        if xpub.hasPrefix("zpub") || xpub.hasPrefix("vpub") {
            externalDescriptor = try Descriptor(descriptor: "wpkh(\(standardKey)/0/*)", network: BDKNetworkConfig.network)
            internalDescriptor = try Descriptor(descriptor: "wpkh(\(standardKey)/1/*)", network: BDKNetworkConfig.network)
        } else if xpub.hasPrefix("ypub") || xpub.hasPrefix("upub") {
            externalDescriptor = try Descriptor(descriptor: "sh(wpkh(\(standardKey)/0/*))", network: BDKNetworkConfig.network)
            internalDescriptor = try Descriptor(descriptor: "sh(wpkh(\(standardKey)/1/*))", network: BDKNetworkConfig.network)
        } else {
            externalDescriptor = try Descriptor(descriptor: "pkh(\(standardKey)/0/*)", network: BDKNetworkConfig.network)
            internalDescriptor = try Descriptor(descriptor: "pkh(\(standardKey)/1/*)", network: BDKNetworkConfig.network)
        }

        return try loadOrCreateDualDescriptorWallet(
            walletId: wallet.id,
            externalDescriptor: externalDescriptor,
            internalDescriptor: internalDescriptor
        )
    }

    // MARK: - Address wallet

    /// Loads (or creates) a single-address watch-only wallet using the `addr()` descriptor.
    func loadAddressWallet(for wallet: Wallet, address: String) throws -> (BitcoinDevKit.Wallet, Persister) {
        let descriptor = try Descriptor(descriptor: "addr(\(address))", network: BDKNetworkConfig.network)
        let dbPath = Self.walletDatabasePath(for: wallet.id)
        let persister = try Persister.newSqlite(path: dbPath)

        do {
            let bdkWallet = try BitcoinDevKit.Wallet.loadSingle(descriptor: descriptor, persister: persister)
            Log.print.info("[BDK] Address wallet loaded from SQLite: \(wallet.id.uuidString)")
            return (bdkWallet, persister)
        } catch {
            Log.print.warning("[BDK] Address wallet load failed for \(wallet.id.uuidString): \(error.localizedDescription). Creating new.")

            try? FileManager.default.removeItem(atPath: dbPath)
            let freshPersister = try Persister.newSqlite(path: dbPath)

            let bdkWallet = try BitcoinDevKit.Wallet.createSingle(
                descriptor: descriptor, network: BDKNetworkConfig.network, persister: freshPersister
            )
            _ = try bdkWallet.persist(persister: freshPersister)
            // addr() descriptors only support incremental sync, so mark
            // full scan as completed to prevent syncOrFullScan from attempting it.
            Self.markFullScanCompleted(for: wallet.id)
            Log.print.info("[BDK] Fresh address wallet created: \(wallet.id.uuidString)")
            return (bdkWallet, freshPersister)
        }
    }

    // MARK: - Shared dual-descriptor loader

    /// Loads an existing dual-descriptor wallet from SQLite, or creates a fresh one
    /// if the database is missing or corrupted.
    func loadOrCreateDualDescriptorWallet(
        walletId: UUID,
        externalDescriptor: Descriptor,
        internalDescriptor: Descriptor
    ) throws -> (BitcoinDevKit.Wallet, Persister) {
        let dbPath = Self.walletDatabasePath(for: walletId)
        let persister = try Persister.newSqlite(path: dbPath)

        do {
            let bdkWallet = try BitcoinDevKit.Wallet.load(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                persister: persister
            )
            Log.print.info("[BDK] Wallet loaded from SQLite: \(walletId.uuidString)")
            return (bdkWallet, persister)
        } catch {
            Log.print.warning("[BDK] Wallet.load failed for \(walletId.uuidString): \(error.localizedDescription). Creating new wallet.")

            try? FileManager.default.removeItem(atPath: dbPath)
            let freshPersister = try Persister.newSqlite(path: dbPath)

            let bdkWallet = try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: BDKNetworkConfig.network,
                persister: freshPersister
            )
            _ = try bdkWallet.persist(persister: freshPersister)
            Self.resetFullScanFlag(for: walletId)
            Log.print.info("[BDK] Fresh wallet created and persisted: \(walletId.uuidString)")
            return (bdkWallet, freshPersister)
        }
    }

    // MARK: - Transaction extraction

    /// Converts BDK canonical transactions into the app's `WalletTransaction` model.
    static func extractTransactions(from bdkWallet: BitcoinDevKit.Wallet) -> [WalletTransaction] {
        bdkWallet.transactions()
            .map { canonical -> WalletTransaction in
                let tx = canonical.transaction
                let txid = tx.computeTxid().description

                let sentReceived = bdkWallet.sentAndReceived(tx: tx)
                let netSats = Int64(sentReceived.received.toSat()) - Int64(sentReceived.sent.toSat())
                let valueBTC = Double(netSats) / 100_000_000.0

                let date: Date
                let isConfirmed: Bool
                switch canonical.chainPosition {
                case .confirmed(let blockTime, _):
                    date = Date(timeIntervalSince1970: TimeInterval(blockTime.confirmationTime))
                    isConfirmed = true
                case .unconfirmed:
                    date = .now
                    isConfirmed = false
                }

                return WalletTransaction(id: UUID(), address: txid, valueBTC: valueBTC, date: date, isConfirmed: isConfirmed)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Address wallet sync (mempool.space API)

    /// Fetches balance and transactions for a single-address wallet using
    /// the mempool.space REST API instead of BDK sync.
    ///
    /// The balance is derived from the address stats (funded − spent for both
    /// confirmed and mempool UTXOs). Transactions are mapped from the API
    /// response into the app's `WalletTransaction` model.
    static func syncAddressWallet(
        address: String,
        api: MempoolSpaceAPIProtocol = MempoolSpaceAPI.shared
    ) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        async let infoTask = api.fetchAddressInfo(address: address)
        async let txsTask = api.fetchAddressTransactions(address: address)

        let info = try await infoTask
        let apiTxs = try await txsTask

        // Balance = total funded − total spent (chain + mempool).
        let chainBalance = info.chainStats.fundedTxoSum - info.chainStats.spentTxoSum
        let mempoolBalance = info.mempoolStats.fundedTxoSum - info.mempoolStats.spentTxoSum
        let totalSats = UInt64(max(0, chainBalance + mempoolBalance))

        // Map API transactions to the app's WalletTransaction model.
        let transactions: [WalletTransaction] = apiTxs.map { tx in
            let received = tx.vout
                .filter { $0.scriptpubkeyAddress == address }
                .reduce(Int64(0)) { $0 + $1.value }

            let sent = tx.vin
                .compactMap { $0.prevout }
                .filter { $0.scriptpubkeyAddress == address }
                .reduce(Int64(0)) { $0 + $1.value }

            let netSats = received - sent
            let valueBTC = Double(netSats) / 100_000_000.0

            let date: Date
            if let blockTime = tx.status.blockTime {
                date = Date(timeIntervalSince1970: TimeInterval(blockTime))
            } else {
                date = .now
            }

            return WalletTransaction(
                id: UUID(),
                address: tx.txid,
                valueBTC: valueBTC,
                date: date,
                isConfirmed: tx.status.confirmed
            )
        }
        .sorted { $0.date > $1.date }

        Log.print.info("[Mempool API] Address \(address): balance = \(totalSats) sats, \(transactions.count) txs")
        return (totalSats, transactions)
    }

    // MARK: - Full-scan state (UserDefaults)

    /// UserDefaults key prefix scoped to the active network so that
    /// signet and mainnet full-scan states never collide.
    private static var fullScanKeyPrefix: String {
        "bdk_full_scan_\(BDKNetworkConfig.networkName)_"
    }

    /// Returns `true` when the wallet has never completed a full scan.
    /// Defaults to `true` for wallets not yet tracked in `UserDefaults`.
    static func needsFullScan(for walletId: UUID) -> Bool {
        !UserDefaults.standard.bool(forKey: "\(fullScanKeyPrefix)\(walletId.uuidString)")
    }

    /// Persists the fact that the given wallet has completed its initial full scan.
    static func markFullScanCompleted(for walletId: UUID) {
        UserDefaults.standard.set(true, forKey: "\(fullScanKeyPrefix)\(walletId.uuidString)")
        Log.print.info("[BDK] Full scan state saved for wallet \(walletId.uuidString)")
    }

    /// Resets the full-scan flag so the next sync performs a full scan.
    static func resetFullScanFlag(for walletId: UUID) {
        UserDefaults.standard.removeObject(forKey: "\(fullScanKeyPrefix)\(walletId.uuidString)")
        Log.print.info("[BDK] Full scan flag reset for wallet \(walletId.uuidString)")
    }

    /// Returns the SQLite database path for the given wallet UUID,
    /// scoped to the active network (signet vs mainnet).
    static func walletDatabasePath(for id: UUID) -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("wallet_\(id.uuidString)_\(BDKNetworkConfig.networkName).sqlite").path
    }

    // MARK: - SLIP-0132 → BIP-32 conversion

    /// Converts a SLIP-0132 extended public key to standard BIP-32 encoding.
    ///
    /// - Mainnet: `zpub`/`ypub` → `xpub` (version bytes `0x0488B21E`)
    /// - Signet/Testnet: `vpub`/`upub` → `tpub` (version bytes `0x043587CF`)
    ///
    /// Returns the key unchanged if it already uses a standard prefix (`xpub`/`tpub`).
    /// BDK's miniscript parser only recognises `xpub`/`tpub`, so this conversion
    /// is required before constructing descriptors.
    static func convertToStandardKey(_ key: String) -> String {
        let targetVersion: [UInt8]

        if key.hasPrefix("zpub") || key.hasPrefix("ypub") {
            // Mainnet SLIP-0132 → xpub
            targetVersion = [0x04, 0x88, 0xB2, 0x1E]
        } else if key.hasPrefix("vpub") || key.hasPrefix("upub") {
            // Signet/Testnet SLIP-0132 → tpub
            targetVersion = [0x04, 0x35, 0x87, 0xCF]
        } else {
            // Already standard (xpub/tpub) or unknown — return unchanged.
            return key
        }

        guard var payload = base58CheckDecode(key) else {
            Log.print.warning("[BDK] Failed to Base58Check-decode key: \(key.prefix(8))…")
            return key
        }

        payload[0] = targetVersion[0]
        payload[1] = targetVersion[1]
        payload[2] = targetVersion[2]
        payload[3] = targetVersion[3]

        return base58CheckEncode(payload)
    }

    // MARK: - Base58Check codec

    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    /// Double-SHA256 convenience.
    private static func doubleSHA256(_ data: [UInt8]) -> [UInt8] {
        let first  = Data(SHA256.hash(data: data))
        let second = Data(SHA256.hash(data: first))
        return Array(second)
    }

    /// Decodes a Base58Check-encoded string, verifies the checksum, and returns
    /// the payload **without** the trailing 4-byte checksum.
    private static func base58CheckDecode(_ string: String) -> [UInt8]? {
        // Count leading '1' characters (each represents a 0x00 byte).
        var leadingZeros = 0
        for ch in string { if ch == "1" { leadingZeros += 1 } else { break } }

        // Convert base58 string → big integer stored in a byte array.
        var result: [UInt8] = [0]
        for char in string {
            guard let digitIndex = base58Alphabet.firstIndex(of: char) else { return nil }
            var carry = digitIndex
            for j in stride(from: result.count - 1, through: 0, by: -1) {
                carry += Int(result[j]) * 58
                result[j] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                result.insert(UInt8(carry & 0xFF), at: 0)
                carry >>= 8
            }
        }

        let bytes = [UInt8](repeating: 0, count: leadingZeros) + result
        guard bytes.count >= 4 else { return nil }

        let payload  = Array(bytes[0 ..< bytes.count - 4])
        let checksum = Array(bytes[bytes.count - 4 ..< bytes.count])
        let expected = Array(doubleSHA256(payload).prefix(4))
        guard checksum == expected else { return nil }

        return payload
    }

    /// Base58Check-encodes a payload (appends a 4-byte double-SHA256 checksum).
    private static func base58CheckEncode(_ payload: [UInt8]) -> String {
        let checksum = Array(doubleSHA256(payload).prefix(4))
        let bytes = payload + checksum

        // Count leading zero bytes (each becomes a '1' in base58).
        var leadingZeros = 0
        for b in bytes { if b == 0 { leadingZeros += 1 } else { break } }

        // Encode big integer → base58.
        var digits: [Character] = []
        var num = bytes
        while !num.allSatisfy({ $0 == 0 }) {
            var remainder = 0
            var quotient: [UInt8] = []
            for byte in num {
                let acc = remainder * 256 + Int(byte)
                let digit = acc / 58
                remainder = acc % 58
                if !quotient.isEmpty || digit > 0 {
                    quotient.append(UInt8(digit))
                }
            }
            digits.append(base58Alphabet[remainder])
            num = quotient.isEmpty ? [0] : quotient
        }

        let prefix = String(repeating: "1", count: leadingZeros)
        return prefix + String(digits.reversed())
    }
}
