import Foundation

// MARK: - Wallet model

/// Represents a tracked wallet entry.
struct Wallet: Identifiable, Codable {

    let id: UUID

    /// User-defined wallet name.
    var name: String

    /// Visual theme that determines the card appearance.
    let theme: WalletTheme

    /// Current balance in BTC.
    let balanceBTC: Double

    /// BIP-39 mnemonic phrase (space-separated words). Nil for watch-only wallets.
    let mnemonicPhrase: String?

    init(id: UUID, name: String, theme: WalletTheme, balanceBTC: Double, mnemonicPhrase: String? = nil) {
        self.id = id
        self.name = name
        self.theme = theme
        self.balanceBTC = balanceBTC
        self.mnemonicPhrase = mnemonicPhrase
    }
}

// MARK: - WalletTransaction model

/// A single Bitcoin transaction associated with a wallet.
struct WalletTransaction: Identifiable {

    let id: UUID

    /// Destination address of the transaction.
    let address: String

    /// Amount transferred, in BTC.
    let valueBTC: Double

    /// Date the transaction was broadcast.
    let date: Date

    /// Truncated address suitable for compact display (e.g. `bc1qxy2kg…x0wlh`).
    var shortAddress: String {
        guard address.count > 18 else { return address }
        return "\(address.prefix(10))…\(address.suffix(6))"
    }

    /// Human-readable relative date (e.g. "2 hours ago").
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

extension WalletTransaction {

    /// Ten fixture transactions used by `MockWalletService`.
    static let mocked: [WalletTransaction] = [
        WalletTransaction(
            id: UUID(), address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            valueBTC: 0.00210000, date: .now.addingTimeInterval(-1 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q8c6fqw2z8pnl0q3qj7x2rkh6vxwnjpz8qk9j3z",
            valueBTC: 0.00045000, date: .now.addingTimeInterval(-3 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
            valueBTC: 0.01200000, date: .now.addingTimeInterval(-7 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q5y2u7gnngl6djrsq0vfk9k7u3ke9aqkrqmne8r",
            valueBTC: 0.00089000, date: .now.addingTimeInterval(-26 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qnp57fy8zjq3uc56mtz8s0spkptfurjp9k77q3d",
            valueBTC: 0.00512000, date: .now.addingTimeInterval(-48 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qhkdrknrwz3cz5f2eue7e7euh5r5q3j8j7m3d3x",
            valueBTC: 0.00033000, date: .now.addingTimeInterval(-72 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qjyp2xa3r7gwrfkjhg2sf9lf68kt2j9mvf0ek0h",
            valueBTC: 0.00750000, date: .now.addingTimeInterval(-5 * 86_400)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qkk3vk9k6s7zqr4vhv0y8u4q3x2w1e5t6r9p2m",
            valueBTC: 0.00190000, date: .now.addingTimeInterval(-7 * 86_400)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q2vx4wk8h1j3n6r5t7e9y2u0i4o8p3l6m9k2j5",
            valueBTC: 0.02100000, date: .now.addingTimeInterval(-10 * 86_400)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q9s3d5f7g1h4k8l2m6n0p4r8v2w5x9y3z7a1c4",
            valueBTC: 0.00067000, date: .now.addingTimeInterval(-14 * 86_400)
        )
    ]
}

// MARK: - Protocol

protocol WalletsViewModelProtocol: ObservableObject {
    var uiState: WalletsUiState { get set }
    func showAddWallet()
    func selectWallet(_ id: UUID)
    func deselectWallet()
    func showRenameAlert()
    func showWalletSettings()
    func updateWalletName(id: UUID, name: String)
    func addWallet(_ wallet: Wallet)
    func deleteWallet(id: UUID)

    /// Generates a new BIP-39 wallet via the wallet service and returns the
    /// creation result (wallet + seed-phrase backup). The caller is responsible
    /// for showing the seed phrase and then calling `addWallet(_:)` on confirm.
    func createWallet() async throws -> WalletCreationResult

    /// Validates `phrase` with the wallet service, creates the wallet, adds it
    /// to the list, and persists it — all in one step.
    func importWallet(phrase: String) async throws
}

// MARK: - UiState

struct WalletsUiState {

    /// Ordered list of wallets — empty until `loadWallets()` completes.
    var wallets: [Wallet] = []

    /// Non-nil while a wallet is selected (detail mode).
    var selectedWalletId: UUID? = nil

    /// Controls whether the "Add Wallet" sheet is presented.
    var isPresentingAddSheet: Bool = false

    /// Controls whether the wallet settings sheet is presented.
    var isPresentingWalletSettings: Bool = false

    /// Controls whether the rename alert is presented.
    var isPresentingRenameAlert: Bool = false

    /// Editable text shown in the rename alert text field.
    var renameText: String = ""

    /// Transactions for the selected wallet — empty until the sync completes.
    var transactions: [WalletTransaction] = []

    /// Live balance for the selected wallet in satoshis.
    /// `nil` while the balance has not yet been fetched (shows loading state).
    var selectedWalletBalanceSats: UInt64? = nil

    /// True while the initial wallet list is being loaded.
    var isLoadingWallets: Bool = false

    /// True while the on-chain balance is being fetched.
    var isLoadingBalance: Bool = false

    /// True while transactions for the selected wallet are being fetched.
    var isLoadingTransactions: Bool = false
}

// MARK: - ViewModel

final class WalletsViewModel: WalletsViewModelProtocol {

    @Published var uiState: WalletsUiState = .init()

    private let walletService: any WalletServiceProtocol

    init(walletService: any WalletServiceProtocol = BDKWalletService()) {
        self.walletService = walletService
        Task { @MainActor in await self.loadWallets() }
    }

    // MARK: - Actions

    func showAddWallet() {
        uiState.isPresentingAddSheet = true
    }

    func showWalletSettings() {
        uiState.isPresentingWalletSettings = true
    }

    func selectWallet(_ id: UUID) {
        uiState.selectedWalletId = id
        guard let wallet = uiState.wallets.first(where: { $0.id == id }) else { return }
        Task { @MainActor in await self.syncSelectedWallet(wallet) }
    }

    func deselectWallet() {
        uiState.selectedWalletId = nil
        uiState.transactions = []
        uiState.selectedWalletBalanceSats = nil
    }

    func showRenameAlert() {
        guard let id = uiState.selectedWalletId,
              let wallet = uiState.wallets.first(where: { $0.id == id }) else { return }
        uiState.renameText = wallet.name
        uiState.isPresentingRenameAlert = true
    }

    func updateWalletName(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let index = uiState.wallets.firstIndex(where: { $0.id == id }) else { return }
        uiState.wallets[index].name = trimmed
        Task { await persistWallet(uiState.wallets[index]) }
    }

    func addWallet(_ wallet: Wallet) {
        uiState.wallets.append(wallet)
        uiState.isPresentingAddSheet = false
        Task { await persistWallet(wallet) }
    }

    func deleteWallet(id: UUID) {
        uiState.wallets.removeAll { $0.id == id }
        uiState.selectedWalletId = nil
        uiState.transactions = []
        uiState.isPresentingWalletSettings = false
        Task { await removePersistedWallet(id: id) }
    }

    @MainActor
    func createWallet() async throws -> WalletCreationResult {
        var result = try await walletService.createNewWallet()
        result.wallet.name = "My Wallet \(uiState.wallets.count + 1)"
        return result
    }

    @MainActor
    func importWallet(phrase: String) async throws {
        let words = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        var wallet = try await walletService.importWallet(from: .seedPhrase(words))
        wallet.name = "Imported Wallet \(uiState.wallets.count + 1)"
        addWallet(wallet)
    }
}

// MARK: - Private async

private extension WalletsViewModel {

    /// Loads persisted wallets from SwiftData on startup.
    @MainActor
    func loadWallets() async {
        uiState.isLoadingWallets = true

        do {
            let stored: [Wallet] = try await SwiftDataStorable.shared.fetchAll(Wallet.self)
            uiState.wallets = stored
        } catch {
            Log.print.error("Failed to load wallets: \(error.localizedDescription)")
            uiState.wallets = []
        }

        uiState.isLoadingWallets = false
    }

    /// Persists a wallet to SwiftData.
    func persistWallet(_ wallet: Wallet) async {
        do {
            try await SwiftDataStorable.shared.save(wallet, id: wallet.id.uuidString)
            Log.print.info("Wallet saved: \(wallet.id.uuidString)")
        } catch {
            Log.print.error("Failed to persist wallet: \(error.localizedDescription)")
        }
    }

    /// Removes a wallet from SwiftData.
    func removePersistedWallet(id: UUID) async {
        do {
            try await SwiftDataStorable.shared.delete(Wallet.self, id: id.uuidString)
            Log.print.info("Wallet deleted: \(id.uuidString)")
        } catch {
            Log.print.error("Failed to delete wallet: \(error.localizedDescription)")
        }
    }

    /// Syncs the selected wallet against the Esplora backend:
    /// first fetches the balance, then fetches the transaction history.
    @MainActor
    func syncSelectedWallet(_ wallet: Wallet) async {
        // Reset state before loading.
        uiState.selectedWalletBalanceSats = nil
        uiState.isLoadingBalance = true
        uiState.isLoadingTransactions = true
        uiState.transactions = []

        // Fetch balance first so the card updates as soon as possible.
        do {
            uiState.selectedWalletBalanceSats = try await walletService.fetchWalletBalance(for: wallet)
        } catch {
            Log.print.error("Balance fetch failed: \(error.localizedDescription)")
        }
        uiState.isLoadingBalance = false

        // Then fetch the full transaction history.
        do {
            uiState.transactions = try await walletService.fetchWalletTransactions(for: wallet)
        } catch {
            Log.print.error("Transactions fetch failed: \(error.localizedDescription)")
        }
        uiState.isLoadingTransactions = false
    }
}
