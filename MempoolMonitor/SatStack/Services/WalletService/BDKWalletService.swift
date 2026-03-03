import BitcoinDevKit
import Foundation

/// Production implementation of `WalletServiceProtocol` backed by the Bitcoin Dev Kit.
///
/// Uses BDK to generate and validate BIP-39 seed phrases, derive BIP-84
/// (native SegWit) descriptors, and initialise a `BitcoinDevKit.Wallet` backed
/// by a per-wallet SQLite database stored in the app's Documents directory.
struct BDKWalletService: WalletServiceProtocol {

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
        let dbPath = Self.walletDatabasePath(for: walletId)
        let persister = try Persister.newSqlite(path: dbPath)
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
            let dbPath = Self.walletDatabasePath(for: walletId)
            let persister = try Persister.newSqlite(path: dbPath)
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

    // MARK: - fetchWalletTransactions

    /// On-chain transaction sync is not yet implemented.
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        return []
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
