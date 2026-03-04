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
        case .esplora:
            return "https://mempool.space/api"
            
        case .electrum:
            return "ssl://electrum.blockstream.info:50002"
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

        let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: .bitcoin)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: .bitcoin)

        let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
        let bdkWallet = try BitcoinDevKit.Wallet(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            network: .bitcoin,
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

            let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
            let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: .bitcoin)
            let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: .bitcoin)

            let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
            let bdkWallet = try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: .bitcoin,
                persister: persister
            )
            // Persist the initial wallet state so Wallet.load succeeds on next open.
            _ = try bdkWallet.persist(persister: persister)
            Log.print.info("[BDK] Imported wallet created and persisted: \(walletId.uuidString)")

            return Wallet(id: walletId, name: "Imported Wallet", theme: .bitcoin, balanceBTC: 0.0, mnemonicPhrase: phrase)

        case .address(let address):
            guard address.hasPrefix("bc1") || address.hasPrefix("1") || address.hasPrefix("3") else {
                throw WalletServiceError.invalidImportSource("'\(address)' does not look like a valid Bitcoin address.")
            }
            return Wallet(id: UUID(), name: "Watch-only", theme: .watchOnly, balanceBTC: 0.0, descriptor: address)

        case .xpub(let key):
            guard key.hasPrefix("xpub") || key.hasPrefix("ypub") || key.hasPrefix("zpub") else {
                throw WalletServiceError.invalidImportSource("'\(key.prefix(8))…' is not a recognised extended public key prefix.")
            }
            return Wallet(id: UUID(), name: "Watch-only", theme: .watchOnly, balanceBTC: 0.0, descriptor: key)

        case .privateKey:
            throw WalletServiceError.invalidImportSource("Private key import is not yet supported.")
        }
    }

    // MARK: - fetchWalletBalance

    /// Synchronises the wallet (full scan or incremental) and returns the total balance in satoshis.
    func fetchWalletBalance(for wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> UInt64 {
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id, onProgress: onProgress)
        return bdkWallet.balance().total.toSat()
    }

    // MARK: - fetchWalletTransactions

    /// Synchronises the wallet (full scan or incremental) and returns the transaction
    /// history sorted newest-first with net BTC values (positive = received, negative = sent).
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id, onProgress: { _ in })
        return Self.extractTransactions(from: bdkWallet)
    }

    // MARK: - syncWallet

    /// Loads the BDK wallet, syncs **once**, and returns both the balance and the
    /// transaction list in a single pass — avoiding the redundant double-sync that
    /// happens when `fetchWalletBalance` and `fetchWalletTransactions` are called
    /// independently.
    func syncWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        let (bdkWallet, persister) = try loadBDKWallet(for: wallet)
        try syncOrFullScan(bdkWallet, persister: persister, walletId: wallet.id, onProgress: onProgress)
        let balance = bdkWallet.balance().total.toSat()
        let transactions = Self.extractTransactions(from: bdkWallet)
        return (balance, transactions)
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
    /// - xpub/ypub/zpub → `loadXpubWallet` (watch-only HD tracking)
    /// - Bitcoin address → `loadAddressWallet` (single-address watch-only)
    func loadBDKWallet(for wallet: Wallet) throws -> (BitcoinDevKit.Wallet, Persister) {
        if wallet.mnemonicPhrase != nil {
            return try loadSeedWallet(for: wallet)
        }

        if let descriptor = wallet.descriptor {
            if descriptor.hasPrefix("xpub") || descriptor.hasPrefix("ypub") || descriptor.hasPrefix("zpub") {
                return try loadXpubWallet(for: wallet, xpub: descriptor)
            }
            if descriptor.hasPrefix("bc1") || descriptor.hasPrefix("1") || descriptor.hasPrefix("3") {
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
        let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .external, network: .bitcoin)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey, keychainKind: .internal, network: .bitcoin)

        return try loadOrCreateDualDescriptorWallet(
            walletId: wallet.id,
            externalDescriptor: externalDescriptor,
            internalDescriptor: internalDescriptor
        )
    }

    // MARK: - Xpub wallet

    /// Loads (or creates) a watch-only HD wallet from an extended public key.
    ///
    /// BDK's miniscript parser only understands standard BIP-32 `xpub` encoding,
    /// so SLIP-0132 keys (`zpub`, `ypub`) are converted to `xpub` first.
    /// The descriptor type is selected based on the **original** prefix:
    /// - `zpub` → `wpkh()` — BIP-84 (native segwit)
    /// - `ypub` → `sh(wpkh())` — BIP-49 (nested segwit)
    /// - `xpub` → `pkh()` — BIP-44 (legacy)
    func loadXpubWallet(for wallet: Wallet, xpub: String) throws -> (BitcoinDevKit.Wallet, Persister) {
        // Convert SLIP-0132 encoding to standard BIP-32 xpub for BDK compatibility.
        let standardKey = Self.convertToXpub(xpub)

        let externalDescriptor: Descriptor
        let internalDescriptor: Descriptor

        if xpub.hasPrefix("zpub") {
            externalDescriptor = try Descriptor(descriptor: "wpkh(\(standardKey)/0/*)", network: .bitcoin)
            internalDescriptor = try Descriptor(descriptor: "wpkh(\(standardKey)/1/*)", network: .bitcoin)
        } else if xpub.hasPrefix("ypub") {
            externalDescriptor = try Descriptor(descriptor: "sh(wpkh(\(standardKey)/0/*))", network: .bitcoin)
            internalDescriptor = try Descriptor(descriptor: "sh(wpkh(\(standardKey)/1/*))", network: .bitcoin)
        } else {
            externalDescriptor = try Descriptor(descriptor: "pkh(\(standardKey)/0/*)", network: .bitcoin)
            internalDescriptor = try Descriptor(descriptor: "pkh(\(standardKey)/1/*)", network: .bitcoin)
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
        let descriptor = try Descriptor(descriptor: "addr(\(address))", network: .bitcoin)
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
                descriptor: descriptor, network: .bitcoin, persister: freshPersister
            )
            _ = try bdkWallet.persist(persister: freshPersister)
            Self.resetFullScanFlag(for: wallet.id)
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
                network: .bitcoin,
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

    /// Resets the full-scan flag so the next sync performs a full scan.
    static func resetFullScanFlag(for walletId: UUID) {
        UserDefaults.standard.removeObject(forKey: "bdk_full_scan_\(walletId.uuidString)")
        Log.print.info("[BDK] Full scan flag reset for wallet \(walletId.uuidString)")
    }

    /// Returns the SQLite database path for the given wallet UUID.
    static func walletDatabasePath(for id: UUID) -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("wallet_\(id.uuidString).sqlite").path
    }

    // MARK: - SLIP-0132 → BIP-32 conversion

    /// Converts a SLIP-0132 extended public key (`zpub`/`ypub`) to standard BIP-32
    /// `xpub` encoding. Returns the key unchanged if it already starts with `xpub`.
    ///
    /// BDK's miniscript parser only recognises `xpub`/`tpub`, so this conversion
    /// is required before constructing descriptors.
    static func convertToXpub(_ key: String) -> String {
        guard key.hasPrefix("zpub") || key.hasPrefix("ypub") else { return key }
        guard var payload = base58CheckDecode(key) else {
            Log.print.warning("[BDK] Failed to Base58Check-decode key: \(key.prefix(8))…")
            return key
        }

        // Replace version bytes with standard xpub (0x0488B21E).
        let xpubVersion: [UInt8] = [0x04, 0x88, 0xB2, 0x1E]
        payload[0] = xpubVersion[0]
        payload[1] = xpubVersion[1]
        payload[2] = xpubVersion[2]
        payload[3] = xpubVersion[3]

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
