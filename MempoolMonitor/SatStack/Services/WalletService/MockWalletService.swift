import Foundation

/// A mock implementation of `WalletServiceProtocol` used for UI previews,
/// unit tests, and development builds where a real wallet backend is not yet wired up.
///
/// All methods simulate realistic async latency (~0.5 s) and return deterministic
/// fixture data so that the interface can be exercised without a live network or
/// hardware (e.g. SatsCard NFC).
///
/// Usage:
/// ```swift
/// let service: WalletServiceProtocol = MockWalletService()
/// let result = try await service.createNewWallet()
/// ```
struct MockWalletService: WalletServiceProtocol {

    // MARK: - createNewWallet

    /// Returns a pre-built HD wallet together with a fixed 12-word seed phrase backup.
    func createNewWallet() async throws -> WalletCreationResult {
        try await simulateDelay()

        let wallet = Wallet(
            id: UUID(),
            name: "New Wallet",
            theme: .bitcoin,
            balanceBTC: 0.0
        )
        let backup = WalletBackup(
            walletId: wallet.id,
            kind: .seedPhrase(MockWalletService.mockSeedPhrase)
        )
        return WalletCreationResult(wallet: wallet, backup: backup)
    }

    // MARK: - importWallet

    /// Returns a wallet whose properties are derived from the provided import source.
    ///
    /// - `.seedPhrase` → `WalletTheme.bitcoin`, full balance fixture
    /// - `.address`    → `WalletTheme.watchOnly`, zero balance
    /// - `.xpub`       → `WalletTheme.watchOnly`, read-only fixture balance
    /// - `.privateKey` → `WalletTheme.bitcoin`, single-key fixture balance
    func importWallet(from source: WalletImportSource) async throws -> Wallet {
        try await simulateDelay()

        switch source {
        case .seedPhrase(let words):
            guard words.count == 12 || words.count == 24 else {
                throw WalletServiceError.invalidImportSource(
                    "Seed phrase must contain 12 or 24 words, got \(words.count)."
                )
            }
            return Wallet(
                id: UUID(),
                name: "Imported HD Wallet",
                theme: .bitcoin,
                balanceBTC: 0.42100000
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
                balanceBTC: 1.00000000
            )

        case .privateKey(let wif):
            guard wif.count >= 51 && wif.count <= 52 else {
                throw WalletServiceError.invalidImportSource(
                    "WIF private key must be 51–52 characters long."
                )
            }
            return Wallet(
                id: UUID(),
                name: "Imported Key Wallet",
                theme: .bitcoin,
                balanceBTC: 0.00210000
            )
        }
    }

    // MARK: - fetchWalletBalance

    /// Returns a deterministic fixture balance in satoshis (0.021 BTC), simulating progress ticks.
    func fetchWalletBalance(for wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> UInt64 {
        try await simulateProgressTicks(onProgress: onProgress)
        return 2_100_000 // 0.021 BTC in satoshis
    }

    // MARK: - fetchWalletTransactions

    /// Returns the shared `WalletTransaction.mocked` fixture list, simulating a
    /// network fetch for the given wallet.
    func fetchWalletTransactions(for wallet: Wallet) async throws -> [WalletTransaction] {
        try await simulateDelay()
        return WalletTransaction.mocked
    }

    // MARK: - syncWallet

    /// Returns fixture balance and transactions in a single call, simulating progress ticks.
    func syncWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        try await simulateProgressTicks(onProgress: onProgress)
        return (balance: 2_100_000, transactions: WalletTransaction.mocked)
    }

    // MARK: - fullScanWallet

    /// Simulates a full scan returning fixture balance and transactions.
    func fullScanWallet(_ wallet: Wallet, onProgress: @escaping @Sendable (Double?) -> Void) async throws -> (balance: UInt64, transactions: [WalletTransaction]) {
        try await simulateProgressTicks(onProgress: onProgress)
        return (balance: 2_100_000, transactions: WalletTransaction.mocked)
    }

    // MARK: - fetchWalletBackup

    /// Returns a seed-phrase backup for `.bitcoin` / `.satsCard` themed wallets
    /// and a watch-only descriptor backup for `.watchOnly` wallets.
    func fetchWalletBackup(for wallet: Wallet) async throws -> WalletBackup {
        try await simulateDelay()

        switch wallet.theme {
        case .watchOnly:
            return WalletBackup(
                walletId: wallet.id,
                kind: .watchOnly(descriptor: "xpub6CUGRUonZSQ4TWtTMmzXdrXDtyPWKiK…")
            )
        case .bitcoin, .satsCard:
            return WalletBackup(
                walletId: wallet.id,
                kind: .seedPhrase(MockWalletService.mockSeedPhrase)
            )
        }
    }
}

// MARK: - Private helpers

private extension MockWalletService {

    /// Simulates realistic I/O latency (0.4 – 0.6 seconds).
    func simulateDelay() async throws {
        let nanoseconds = UInt64.random(in: 400_000_000...600_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    /// Simulates a sync with 5 progress ticks over ~0.5 seconds.
    func simulateProgressTicks(onProgress: @escaping @Sendable (Double?) -> Void) async throws {
        let steps = 5
        for step in 1...steps {
            try await Task.sleep(nanoseconds: 100_000_000)
            onProgress(Double(step) / Double(steps))
        }
    }

    /// Deterministic 12-word BIP-39 fixture phrase — **never use in production**.
    static let mockSeedPhrase: [String] = [
        "abandon", "ability", "able", "about",
        "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident"
    ]
}
