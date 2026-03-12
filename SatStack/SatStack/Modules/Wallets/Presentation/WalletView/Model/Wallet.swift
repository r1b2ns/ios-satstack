import Combine
import Foundation

/// Represents a tracked wallet entry.
struct Wallet: Identifiable, Codable {

    let id: UUID

    /// User-defined wallet name.
    var name: String

    /// Visual theme that determines the card appearance.
    let theme: WalletTheme

    /// Current balance in BTC. Updated and persisted after each successful sync.
    var balanceBTC: Double

    /// BIP-39 mnemonic phrase (space-separated words). Nil for watch-only wallets.
    ///
    /// **Not encoded/decoded.** Loaded exclusively from the iOS Keychain after SwiftData
    /// deserialization — never written to SwiftData storage.
    var mnemonicPhrase: String? = nil

    /// Original import descriptor (xpub or Bitcoin address) for watch-only wallets.
    /// Used for duplicate detection. Nil for seed-based wallets.
    ///
    /// **Not encoded/decoded.** Loaded exclusively from the iOS Keychain after SwiftData
    /// deserialization — never written to SwiftData storage.
    var descriptor: String? = nil

    /// BIP-84 account-level extended public key (xpub) used by `WalletMempoolService`
    /// to sync balance and transactions via the mempool.space xpub API.
    ///
    /// - Seed wallets: derived at `m/84h/0h/0h` and stored in the Keychain.
    /// - xpub wallets: equal to `descriptor` (the import key itself).
    /// - Address wallets: always `nil` (single-address, no xpub).
    ///
    /// **Not encoded/decoded.** Loaded exclusively from the iOS Keychain after SwiftData
    /// deserialization — never written to SwiftData storage.
    var xpub: String? = nil

    init(id: UUID, name: String, theme: WalletTheme, balanceBTC: Double, mnemonicPhrase: String? = nil, descriptor: String? = nil) {
        self.id = id
        self.name = name
        self.theme = theme
        self.balanceBTC = balanceBTC
        self.mnemonicPhrase = mnemonicPhrase
        self.descriptor = descriptor
    }

    /// Whether this wallet is a single-address watch-only import (bc1/tb1/1/3).
    /// Address wallets use the mempool.space API instead of BDK for sync.
    var isAddressWallet: Bool {
        guard mnemonicPhrase == nil, let descriptor else { return false }
        let addressPrefixes = ["bc1", "tb1", "1", "3"]
        return addressPrefixes.contains(where: { descriptor.hasPrefix($0) })
    }

    // MARK: - Codable (sensitive fields excluded)

    /// Encodes/decodes only the non-sensitive fields persisted in SwiftData.
    /// `mnemonicPhrase` and `descriptor` are intentionally omitted — they live
    /// exclusively in the iOS Keychain, keyed by the wallet's UUID.
    private enum CodingKeys: String, CodingKey {
        case id, name, theme, balanceBTC
    }
}
