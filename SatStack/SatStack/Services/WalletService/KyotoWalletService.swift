import BitcoinDevKit
import CryptoKit
import Foundation

// MARK: - KyotoWalletService

/// `WalletServiceProtocol` implementation backed by BDK's Compact Block Filter (CBF) light client.
///
/// Unlike `BDKWalletService` which relies on Electrum/Esplora servers, this service
/// connects directly to the Bitcoin P2P network using BIP 157/158 compact block filters.
/// A `CbfNode` runs on a background thread, fetching headers and filters, while the
/// `CbfClient` receives wallet updates and can broadcast transactions.
///
/// **Note:** This service is not yet wired into the app. It is created as a standalone
/// implementation for future integration when Kyoto sync mode is enabled.
struct KyotoWalletService: WalletServiceProtocol {

    /// Number of P2P connections the light client maintains.
    private let connectionCount: UInt8 = 2

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
        _ = try bdkWallet.persist(persister: persister)
        Log.print.info("[Kyoto] New wallet created and persisted: \(walletId.uuidString)")

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
            _ = try bdkWallet.persist(persister: persister)
            Log.print.info("[Kyoto] Imported wallet created and persisted: \(walletId.uuidString)")

            return Wallet(id: walletId, name: "Imported Wallet", theme: .bitcoin, balanceBTC: 0.0, mnemonicPhrase: phrase)

        case .address(let address):
            let validPrefixes = ["bc1", "tb1", "1", "3"]
            guard validPrefixes.contains(where: { address.hasPrefix($0) }) else {
                throw WalletServiceError.invalidImportSource("'\(address)' does not look like a valid Bitcoin address.")
            }
            let walletId = UUID()
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

    func fetchWalletBalance(for wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> UInt64 {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            let result = try await BDKWalletService.syncAddressWallet(address: address)
            return result.balance
        }
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try await syncViaCbf(bdkWallet, persister: persister, walletId: wallet.id, onProgress: onProgress)
        return bdkWallet.balance().total.toSat()
    }

    // MARK: - fetchWalletTransactions

    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            let result = try await BDKWalletService.syncAddressWallet(address: address)
            return result.transactions
        }
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try await syncViaCbf(bdkWallet, persister: persister, walletId: wallet.id, onProgress: { _ in })
        return BDKWalletService.extractTransactions(from: bdkWallet)
    }

    // MARK: - syncWallet

    func syncWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            return try await BDKWalletService.syncAddressWallet(address: address)
        }
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try await syncViaCbf(bdkWallet, persister: persister, walletId: wallet.id, onProgress: onProgress)
        let balance = bdkWallet.balance().total.toSat()
        let transactions = BDKWalletService.extractTransactions(from: bdkWallet)
        return (balance, transactions)
    }

    // MARK: - fullScanWallet

    func fullScanWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        if wallet.isAddressWallet, let address = wallet.descriptor {
            return try await BDKWalletService.syncAddressWallet(address: address)
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
        Log.print.info("[Kyoto] Receive address derived (index \(addressInfo.index)): \(address)")
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

        let recipientAddress = try Address(address: address, network: BDKNetworkConfig.network)
        let script = recipientAddress.scriptPubkey()
        let amount = Amount.fromSat(satoshi: amountSats)
        let rate = try FeeRate.fromSatPerVb(satVb: feeRateSatVB)

        let psbt = try TxBuilder()
            .addRecipient(script: script, amount: amount)
            .feeRate(feeRate: rate)
            .finish(wallet: bdkWallet)

        let signed = try bdkWallet.sign(psbt: psbt)
        guard signed else {
            throw WalletServiceError.broadcastFailed("Transaction signing failed — wallet may lack a private key.")
        }

        let tx = try psbt.extractTx()
        let txid = tx.computeTxid()

        // Broadcast via CBF node for true P2P broadcasting.
        let components = buildCbfComponents(wallet: bdkWallet, walletId: wallet.id)
        components.node.run()
        defer {
            try? components.client.shutdown()
        }
        _ = try await components.client.broadcast(transaction: tx)

        _ = try bdkWallet.persist(persister: persister)
        let txidString = txid.description
        Log.print.info("[Kyoto] Transaction broadcast successfully: \(txidString)")

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

// MARK: - CBF Sync Logic

private extension KyotoWalletService {

    /// Builds `CbfComponents` (node + client) for the given BDK wallet.
    func buildCbfComponents(wallet bdkWallet: BitcoinDevKit.Wallet, walletId: UUID) -> CbfComponents {
        let dataDir = Self.cbfDataDirectory(for: walletId)

        // Ensure the CBF data directory exists.
        try? FileManager.default.createDirectory(
            atPath: dataDir,
            withIntermediateDirectories: true
        )

        let scanType: ScanType = Self.needsFullScan(for: walletId) ? .sync : .sync

        return CbfBuilder()
            .dataDir(dataDir: dataDir)
            .connections(connections: connectionCount)
            .scanType(scanType: scanType)
            .build(wallet: bdkWallet)
    }

    /// Runs the CBF node, waits for the first wallet update, applies it, and shuts down.
    func syncViaCbf(
        _ bdkWallet: BitcoinDevKit.Wallet,
        persister: Persister,
        walletId: UUID,
        onProgress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        let components = buildCbfComponents(wallet: bdkWallet, walletId: walletId)

        // Start the node on a detached OS thread.
        components.node.run()
        Log.print.info("[Kyoto] CBF node started for wallet \(walletId.uuidString)")

        // Report indeterminate progress — CBF sync doesn't provide granular progress.
        onProgress(nil)

        do {
            // Wait for the node to sync and return a wallet update.
            let update = try await components.client.update()
            Log.print.info("[Kyoto] Received update for wallet \(walletId.uuidString)")

            // Apply the update to the BDK wallet and persist.
            try bdkWallet.applyUpdate(update: update)
            let persisted = try bdkWallet.persist(persister: persister)
            Log.print.info("[Kyoto] Wallet \(walletId.uuidString) synced. Persisted: \(persisted)")

            // Mark full scan as completed on first successful sync.
            if Self.needsFullScan(for: walletId) {
                Self.markFullScanCompleted(for: walletId)
            }

            // Signal completion.
            onProgress(1.0)
        } catch {
            Log.print.error("[Kyoto] Sync failed for wallet \(walletId.uuidString): \(error.localizedDescription)")
            throw WalletServiceError.unknown("CBF sync failed: \(error.localizedDescription)")
        }

        // Shut down the node.
        do {
            try components.client.shutdown()
            Log.print.info("[Kyoto] CBF node stopped for wallet \(walletId.uuidString)")
        } catch {
            Log.print.warning("[Kyoto] Failed to shut down CBF node: \(error.localizedDescription)")
        }
    }
}

// MARK: - Wallet Loading

private extension KyotoWalletService {

    /// Identifies the wallet type and loads the BDK wallet.
    /// Reuses the same loading logic as `BDKWalletService`.
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

    func loadXpubWallet(for wallet: Wallet, xpub: String) throws -> (BitcoinDevKit.Wallet, Persister) {
        let standardKey = BDKWalletService.convertToStandardKey(xpub)

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

    func loadAddressWallet(for wallet: Wallet, address: String) throws -> (BitcoinDevKit.Wallet, Persister) {
        let descriptor = try Descriptor(descriptor: "addr(\(address))", network: BDKNetworkConfig.network)
        let dbPath = Self.walletDatabasePath(for: wallet.id)
        let persister = try Persister.newSqlite(path: dbPath)

        do {
            let bdkWallet = try BitcoinDevKit.Wallet.loadSingle(descriptor: descriptor, persister: persister)
            Log.print.info("[Kyoto] Address wallet loaded from SQLite: \(wallet.id.uuidString)")
            return (bdkWallet, persister)
        } catch {
            Log.print.warning("[Kyoto] Address wallet load failed for \(wallet.id.uuidString): \(error.localizedDescription). Creating new.")

            try? FileManager.default.removeItem(atPath: dbPath)
            let freshPersister = try Persister.newSqlite(path: dbPath)

            let bdkWallet = try BitcoinDevKit.Wallet.createSingle(
                descriptor: descriptor, network: BDKNetworkConfig.network, persister: freshPersister
            )
            _ = try bdkWallet.persist(persister: freshPersister)
            Self.markFullScanCompleted(for: wallet.id)
            Log.print.info("[Kyoto] Fresh address wallet created: \(wallet.id.uuidString)")
            return (bdkWallet, freshPersister)
        }
    }

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
            Log.print.info("[Kyoto] Wallet loaded from SQLite: \(walletId.uuidString)")
            return (bdkWallet, persister)
        } catch {
            Log.print.warning("[Kyoto] Wallet.load failed for \(walletId.uuidString): \(error.localizedDescription). Creating new wallet.")

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
            Log.print.info("[Kyoto] Fresh wallet created and persisted: \(walletId.uuidString)")
            return (bdkWallet, freshPersister)
        }
    }
}

// MARK: - Paths & Full-Scan State

private extension KyotoWalletService {

    /// UserDefaults key prefix scoped to the active network.
    static var fullScanKeyPrefix: String {
        "bdk_full_scan_\(BDKNetworkConfig.networkName)_"
    }

    static func needsFullScan(for walletId: UUID) -> Bool {
        !UserDefaults.standard.bool(forKey: "\(fullScanKeyPrefix)\(walletId.uuidString)")
    }

    static func markFullScanCompleted(for walletId: UUID) {
        UserDefaults.standard.set(true, forKey: "\(fullScanKeyPrefix)\(walletId.uuidString)")
        Log.print.info("[Kyoto] Full scan state saved for wallet \(walletId.uuidString)")
    }

    static func resetFullScanFlag(for walletId: UUID) {
        UserDefaults.standard.removeObject(forKey: "\(fullScanKeyPrefix)\(walletId.uuidString)")
        Log.print.info("[Kyoto] Full scan flag reset for wallet \(walletId.uuidString)")
    }

    /// SQLite database path for wallet persistence (shared with BDKWalletService).
    static func walletDatabasePath(for id: UUID) -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("wallet_\(id.uuidString)_\(BDKNetworkConfig.networkName).sqlite").path
    }

    /// Dedicated directory for CBF block headers and peer data.
    static func cbfDataDirectory(for walletId: UUID) -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("kyoto_\(walletId.uuidString)_\(BDKNetworkConfig.networkName)").path
    }
}
