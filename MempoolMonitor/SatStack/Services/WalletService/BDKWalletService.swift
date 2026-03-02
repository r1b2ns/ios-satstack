import BitcoinDevKit
import Foundation

/// Production implementation of `WalletServiceProtocol` backed by the Bitcoin Dev Kit.
///
/// Uses BDK's `Mnemonic` to generate and validate BIP-39 seed phrases.
/// On-chain transaction fetching is not yet implemented — it returns an empty list
/// until a full Electrum / mempool.space sync layer is wired up.
struct BDKWalletService: WalletServiceProtocol {

    // MARK: - createNewWallet

    /// Generates a new 12-word BIP-39 mnemonic and returns the corresponding wallet.
    func createNewWallet() async throws -> WalletCreationResult {
        let mnemonic = Mnemonic(wordCount: .words12)
        let phrase = mnemonic.description
        let words = phrase.components(separatedBy: " ")

        let wallet = Wallet(
            id: UUID(),
            name: "My Wallet",
            theme: .bitcoin,
            balanceBTC: 0.0,
            mnemonicPhrase: phrase
        )
        let backup = WalletBackup(
            walletId: wallet.id,
            kind: .seedPhrase(words)
        )
        return WalletCreationResult(wallet: wallet, backup: backup)
    }

    // MARK: - importWallet

    /// Imports a wallet from a BIP-39 seed phrase, validating it with BDK.
    func importWallet(from source: WalletImportSource) async throws -> Wallet {
        switch source {
        case .seedPhrase(let words):
            let phrase = words.joined(separator: " ")
            _ = try Mnemonic.fromString(mnemonic: phrase)
            return Wallet(
                id: UUID(),
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
