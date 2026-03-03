import BitcoinDevKit
import Foundation

/// Production implementation of `WalletServiceProtocol` backed by the Bitcoin Dev Kit.
///
/// Uses BDK to generate and validate BIP-39 seed phrases, derive BIP-84
/// (native SegWit) descriptors, and initialise a `BitcoinDevKit.Wallet` backed
/// by a per-wallet SQLite database stored in the app's Documents directory.
/// Live balance and transaction data are fetched via the mempool.space Esplora API.
struct BDKWalletService: WalletServiceProtocol {

    /// Esplora endpoint used for wallet synchronisation.
    private static let esploraUrl = "https://mempool.space/api"

    // MARK: - createNewWallet

    /// Generates a new 12-word BIP-39 mnemonic, derives BIP-84 descriptors and
    /// creates a persisted BDK wallet to validate the full key-derivation chain.
    func createNewWallet() async throws -> WalletCreationResult {
        let mnemonic = Mnemonic(wordCount: .words12)
        let phrase = mnemonic.description
        let words = phrase.components(separatedBy: " ")
        let walletId = UUID()

        // Derive BIP-84 (native SegWit) descriptors from the mnemonic.
        let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(
            secretKey: secretKey,
            keychainKind: .external,
            network: .bitcoin
        )
        let internalDescriptor = Descriptor.newBip84(
            secretKey: secretKey,
            keychainKind: .internal,
            network: .bitcoin
        )

        // Initialise a SQLite-backed BDK wallet to validate descriptor setup.
        let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
        _ = try BitcoinDevKit.Wallet(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            network: .bitcoin,
            persister: persister
        )

        let wallet = Wallet(
            id: walletId,
            name: "My Wallet",
            theme: .bitcoin,
            balanceBTC: 0.0,
            mnemonicPhrase: phrase
        )
        let backup = WalletBackup(walletId: walletId, kind: .seedPhrase(words))
        return WalletCreationResult(wallet: wallet, backup: backup)
    }

    // MARK: - importWallet

    /// Imports a wallet from a BIP-39 seed phrase, validating it with BDK and
    /// deriving BIP-84 descriptors to confirm the phrase is usable.
    func importWallet(from source: WalletImportSource) async throws -> Wallet {
        switch source {
        case .seedPhrase(let words):
            let phrase = words.joined(separator: " ")
            let mnemonic = try Mnemonic.fromString(mnemonic: phrase)
            let walletId = UUID()

            // Derive and validate BIP-84 descriptors.
            let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
            let externalDescriptor = Descriptor.newBip84(
                secretKey: secretKey,
                keychainKind: .external,
                network: .bitcoin
            )
            let internalDescriptor = Descriptor.newBip84(
                secretKey: secretKey,
                keychainKind: .internal,
                network: .bitcoin
            )

            // Initialise a SQLite-backed BDK wallet to confirm the full setup.
            let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: walletId))
            _ = try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: .bitcoin,
                persister: persister
            )

            return Wallet(
                id: walletId,
                name: "Imported Wallet",
                theme: .bitcoin,
                balanceBTC: 0.0,
                mnemonicPhrase: phrase
            )

        case .address(let address):
            guard address.hasPrefix("bc1") || address.hasPrefix("1") || address.hasPrefix("3") else {
                throw WalletServiceError.invalidImportSource(
                    "'\(address)' does not look like a valid Bitcoin address."
                )
            }
            return Wallet(
                id: UUID(),
                name: "Watch-only Address",
                theme: .watchOnly,
                balanceBTC: 0.0
            )

        case .xpub(let key):
            guard key.hasPrefix("xpub") || key.hasPrefix("ypub") || key.hasPrefix("zpub") else {
                throw WalletServiceError.invalidImportSource(
                    "'\(key.prefix(8))…' is not a recognised extended public key prefix."
                )
            }
            return Wallet(
                id: UUID(),
                name: "Watch-only xpub",
                theme: .watchOnly,
                balanceBTC: 0.0
            )

        case .privateKey:
            throw WalletServiceError.invalidImportSource(
                "Private key import is not yet supported."
            )
        }
    }

    // MARK: - fetchWalletBalance

    /// Performs a full Esplora scan via mempool.space and returns the wallet's
    /// total balance in satoshis (confirmed + trusted-pending).
    func fetchWalletBalance(for wallet: Wallet) async throws -> UInt64 {
        let bdkWallet = try loadBDKWallet(for: wallet)
        try syncWithEsplora(bdkWallet)
        return bdkWallet.balance().total.toSat()
    }

    // MARK: - fetchWalletTransactions

    /// Performs a full Esplora scan and returns the wallet's transaction history,
    /// sorted newest-first. Each entry shows the net BTC value from the wallet's
    /// perspective (positive = received, negative = sent).
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        let bdkWallet = try loadBDKWallet(for: wallet)
        try syncWithEsplora(bdkWallet)

        return bdkWallet.transactions()
            .map { canonical -> WalletTransaction in
                let tx = canonical.transaction
                let txid = tx.computeTxid().description

                // Net value from the wallet's perspective.
                let sentReceived = bdkWallet.sentAndReceived(tx: tx)
                let netSats = Int64(sentReceived.received.toSat()) - Int64(sentReceived.sent.toSat())
                let valueBTC = Double(netSats) / 100_000_000.0

                // Resolve confirmation date.
                let date: Date
                switch canonical.chainPosition {
                case .confirmed(let blockTime, _):
                    date = Date(timeIntervalSince1970: TimeInterval(blockTime.confirmationTime))
                case .unconfirmed:
                    date = .now
                }

                return WalletTransaction(
                    id: UUID(),
                    address: txid,
                    valueBTC: valueBTC,
                    date: date
                )
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - fetchWalletBackup

    /// Returns the stored seed phrase backup for HD wallets.
    func fetchWalletBackup(for wallet: Wallet) async throws -> WalletBackup {
        guard let phrase = wallet.mnemonicPhrase else {
            throw WalletServiceError.backupUnavailable
        }
        let words = phrase.components(separatedBy: " ")
        return WalletBackup(walletId: wallet.id, kind: .seedPhrase(words))
    }
}

// MARK: - Private helpers

private extension BDKWalletService {

    /// Loads (or creates) the on-disk BDK wallet for the given `Wallet`.
    ///
    /// Tries `Wallet.load` first so that the existing keychain index is preserved
    /// across restarts; falls back to `Wallet.init` when no prior database exists.
    func loadBDKWallet(for wallet: Wallet) throws -> BitcoinDevKit.Wallet {
        guard let phrase = wallet.mnemonicPhrase else {
            throw WalletServiceError.unknown("No mnemonic available for this wallet.")
        }

        let mnemonic = try Mnemonic.fromString(mnemonic: phrase)
        let secretKey = DescriptorSecretKey(network: .bitcoin, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(
            secretKey: secretKey,
            keychainKind: .external,
            network: .bitcoin
        )
        let internalDescriptor = Descriptor.newBip84(
            secretKey: secretKey,
            keychainKind: .internal,
            network: .bitcoin
        )

        let persister = try Persister.newSqlite(path: Self.walletDatabasePath(for: wallet.id))

        // Attempt to load the existing wallet; create it fresh if none is found.
        do {
            return try BitcoinDevKit.Wallet.load(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                persister: persister
            )
        } catch {
            return try BitcoinDevKit.Wallet(
                descriptor: externalDescriptor,
                changeDescriptor: internalDescriptor,
                network: .bitcoin,
                persister: persister
            )
        }
    }

    /// Performs a full-scan against the mempool.space Esplora backend and
    /// applies the result to `bdkWallet` so its UTXO and tx sets are up to date.
    func syncWithEsplora(_ bdkWallet: BitcoinDevKit.Wallet) throws {
        let client = EsploraClient(url: Self.esploraUrl)
        let request = try bdkWallet.startFullScan().build()
        let update = try client.fullScan(
            request: request,
            stopGap: 20,
            parallelRequests: 4
        )
        try bdkWallet.applyUpdate(update: update)
        Log.print.info("Wallet synced successfully via Esplora.")
    }

    /// Returns the file-system path for the SQLite database associated with a wallet.
    ///
    /// Each wallet gets its own database file inside the app's Documents directory,
    /// named after the wallet's UUID to avoid collisions.
    static func walletDatabasePath(for id: UUID) -> String {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return documentsDir
            .appendingPathComponent("wallet_\(id.uuidString).sqlite")
            .path
    }
}
