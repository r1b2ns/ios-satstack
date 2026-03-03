import Foundation

// MARK: - WalletImportSource

/// The source from which a wallet is reconstructed during an import flow.
///
/// Multiple import formats are supported so the service layer can handle
/// HD wallets, extended public keys, watch-only addresses, and raw private keys
/// through a single entry point.
enum WalletImportSource {

    /// BIP-39 mnemonic word list (12 or 24 words).
    case seedPhrase([String])

    /// A single Bitcoin address imported in watch-only mode.
    case address(String)

    /// An extended public key (xpub / ypub / zpub) for watch-only HD tracking.
    case xpub(String)

    /// A Wallet Import Format (WIF) encoded private key.
    case privateKey(String)
}

// MARK: - WalletBackupKind

/// The type of backup data available for a wallet.
enum WalletBackupKind {

    /// BIP-39 seed phrase for a fully-owned HD wallet.
    ///
    /// Storing or displaying these words must be done with extreme care.
    case seedPhrase([String])

    /// A watch-only descriptor (address or xpub) that carries no spending capability.
    ///
    /// No sensitive backup is needed, only the descriptor itself.
    case watchOnly(descriptor: String)
}

// MARK: - WalletBackup

/// Backup metadata associated with a wallet.
struct WalletBackup {

    /// The wallet this backup belongs to.
    let walletId: UUID

    /// The kind and payload of the backup.
    let kind: WalletBackupKind
}

// MARK: - WalletCreationResult

/// The result returned after successfully creating a brand-new wallet.
struct WalletCreationResult {

    /// The newly created wallet record. Mutable so the caller can apply a display name.
    var wallet: Wallet

    /// The backup that must be shown to and confirmed by the user.
    let backup: WalletBackup
}

// MARK: - WalletServiceError

/// Errors thrown by `WalletServiceProtocol` implementations.
enum WalletServiceError: LocalizedError {

    /// The import source could not be parsed or validated.
    case invalidImportSource(String)

    /// No backup exists for the requested wallet (e.g. watch-only).
    case backupUnavailable

    /// A generic failure with an underlying reason.
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidImportSource(let reason): return "Invalid import source: \(reason)"
        case .backupUnavailable:               return "No backup is available for this wallet."
        case .unknown(let reason):             return "Wallet service error: \(reason)"
        }
    }
}

// MARK: - WalletServiceProtocol

/// Abstracts wallet lifecycle operations, allowing multiple concrete backends
/// (e.g. a built-in HD wallet library, SatsCard NFC reader) to share the same
/// interface and be swapped without touching the UI layer.
///
/// All methods are `async throws` so implementations can perform key derivation,
/// network requests, or NFC I/O without blocking the caller.
///
/// ```swift
/// let service: WalletServiceProtocol = MockWalletService()
///
/// // Create a new HD wallet
/// let result = try await service.createNewWallet()
///
/// // Import from seed phrase
/// let imported = try await service.importWallet(from: .seedPhrase(["word1", …]))
///
/// // Import a watch-only address
/// let watchOnly = try await service.importWallet(from: .address("bc1q…"))
///
/// // Fetch transactions
/// let txs = try await service.fetchWalletTransactions(for: result.wallet)
///
/// // Retrieve backup
/// let backup = try await service.fetchWalletBackup(for: result.wallet)
/// ```
protocol WalletServiceProtocol {

    /// Creates a brand-new HD wallet with a freshly generated BIP-39 seed phrase.
    ///
    /// - Returns: A `WalletCreationResult` containing the new wallet record and
    ///   the backup seed phrase the user must acknowledge.
    func createNewWallet() async throws -> WalletCreationResult

    /// Imports a wallet from an external source.
    ///
    /// The `source` parameter determines which kind of wallet is created:
    /// - `.seedPhrase` → full HD wallet with signing capability
    /// - `.address` / `.xpub` → watch-only wallet (no spending)
    /// - `.privateKey` → single-key wallet with signing capability
    ///
    /// - Parameter source: The credential or descriptor used to reconstruct the wallet.
    /// - Returns: The imported `Wallet` record, ready for use.
    func importWallet(from source: WalletImportSource) async throws -> Wallet

    /// Fetches the on-chain transaction history for the given wallet.
    ///
    /// Implementations are expected to query the relevant blockchain backend
    /// (e.g. mempool.space, Electrum) and return transactions in
    /// reverse-chronological order (newest first).
    ///
    /// - Parameter wallet: The wallet whose transactions should be fetched.
    /// - Returns: A list of `WalletTransaction` entries, newest first.
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction]

    /// Retrieves the backup data for the given wallet.
    ///
    /// For HD wallets this returns the seed phrase. For watch-only wallets
    /// this returns the address or xpub descriptor. Callers should display
    /// seed phrase words in a secure, screenshot-blocked surface.
    ///
    /// - Parameter wallet: The wallet whose backup should be retrieved.
    /// - Returns: A `WalletBackup` with the appropriate `WalletBackupKind`.
    /// - Throws: `WalletServiceError.backupUnavailable` if no backup exists.
    func fetchWalletBackup(for wallet: Wallet) async throws -> WalletBackup
}
