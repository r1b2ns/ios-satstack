import Combine
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

    /// Transaction ID or destination address.
    let address: String

    /// Net amount in BTC from the wallet's perspective (positive = received, negative = sent).
    let valueBTC: Double

    /// Date the transaction was broadcast or confirmed.
    let date: Date

    /// Truncated identifier suitable for compact display (e.g. `bc1qxy2kg…x0wlh`).
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
        WalletTransaction(id: UUID(), address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                          valueBTC:  0.00210000, date: .now.addingTimeInterval(-1 * 3_600)),
        WalletTransaction(id: UUID(), address: "bc1q8c6fqw2z8pnl0q3qj7x2rkh6vxwnjpz8qk9j3z",
                          valueBTC:  0.00045000, date: .now.addingTimeInterval(-3 * 3_600)),
        WalletTransaction(id: UUID(), address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
                          valueBTC:  0.01200000, date: .now.addingTimeInterval(-7 * 3_600)),
        WalletTransaction(id: UUID(), address: "bc1q5y2u7gnngl6djrsq0vfk9k7u3ke9aqkrqmne8r",
                          valueBTC:  0.00089000, date: .now.addingTimeInterval(-26 * 3_600)),
        WalletTransaction(id: UUID(), address: "bc1qnp57fy8zjq3uc56mtz8s0spkptfurjp9k77q3d",
                          valueBTC:  0.00512000, date: .now.addingTimeInterval(-48 * 3_600)),
        WalletTransaction(id: UUID(), address: "bc1qhkdrknrwz3cz5f2eue7e7euh5r5q3j8j7m3d3x",
                          valueBTC:  0.00033000, date: .now.addingTimeInterval(-72 * 3_600)),
        WalletTransaction(id: UUID(), address: "bc1qjyp2xa3r7gwrfkjhg2sf9lf68kt2j9mvf0ek0h",
                          valueBTC:  0.00750000, date: .now.addingTimeInterval(-5 * 86_400)),
        WalletTransaction(id: UUID(), address: "bc1qkk3vk9k6s7zqr4vhv0y8u4q3x2w1e5t6r9p2m",
                          valueBTC:  0.00190000, date: .now.addingTimeInterval(-7 * 86_400)),
        WalletTransaction(id: UUID(), address: "bc1q2vx4wk8h1j3n6r5t7e9y2u0i4o8p3l6m9k2j5",
                          valueBTC:  0.02100000, date: .now.addingTimeInterval(-10 * 86_400)),
        WalletTransaction(id: UUID(), address: "bc1q9s3d5f7g1h4k8l2m6n0p4r8v2w5x9y3z7a1c4",
                          valueBTC: -0.00067000, date: .now.addingTimeInterval(-14 * 86_400))
    ]
}

// MARK: - WalletSyncState

/// Lifecycle state of an on-chain wallet synchronisation.
enum WalletSyncState: Equatable {

    /// Sync has not been triggered yet for this session.
    case idle

    /// A full scan or incremental sync is currently running.
    case syncing

    /// The last sync completed successfully.
    case synced

    /// The last sync failed with the given reason.
    case failed(String)
}

// MARK: - WalletsViewModelProtocol

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

    /// Generates a new BIP-39 wallet via the service. Caller must show the seed
    /// phrase and then call `addWallet(_:)` on confirm.
    func createWallet() async throws -> WalletCreationResult

    /// Validates the phrase with the wallet service, creates the wallet, adds it
    /// to the list and persists it — all in one step.
    func importWallet(phrase: String) async throws
}

// MARK: - WalletsUiState

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

    /// Live balance for the currently selected wallet in satoshis.
    /// `nil` means the balance has not been fetched yet (loading state).
    var selectedWalletBalanceSats: UInt64? = nil

    /// Per-wallet balances in satoshis, populated by the background sync
    /// and by detail-view syncs.
    var walletBalances: [UUID: UInt64] = [:]

    /// Per-wallet sync lifecycle state. Updated by both background sync
    /// (on launch) and the detail-view sync (on wallet selection).
    var walletSyncStates: [UUID: WalletSyncState] = [:]

    /// True while the initial wallet list is being loaded.
    var isLoadingWallets: Bool = false

    /// True while transactions for the selected wallet are being fetched.
    var isLoadingTransactions: Bool = false
}

// MARK: - WalletsViewModel

final class WalletsViewModel: WalletsViewModelProtocol {

    @Published var uiState: WalletsUiState = .init()

    private let walletService: any WalletServiceProtocol

    /// Stores Combine subscriptions created by `syncAllWalletsOnLaunch()`.
    private var syncCancellables = Set<AnyCancellable>()

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
        uiState.walletSyncStates.removeValue(forKey: id)
        uiState.walletBalances.removeValue(forKey: id)
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

    /// Loads persisted wallets from SwiftData on startup, then triggers
    /// a background Esplora sync for all wallets via Combine.
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

        // Kick off background sync for every loaded wallet.
        syncAllWalletsOnLaunch()
    }

    // MARK: - Background sync (Combine)

    /// Creates one `BDKWalletService` instance per wallet and syncs them all
    /// in parallel using `Publishers.MergeMany`. Each wallet's sync state and
    /// balance are updated on the main thread as results arrive.
    @MainActor
    func syncAllWalletsOnLaunch() {
        let wallets = uiState.wallets
        guard !wallets.isEmpty else { return }

        // Mark every wallet as syncing immediately so the UI reacts at once.
        for wallet in wallets {
            uiState.walletSyncStates[wallet.id] = .syncing
        }

        struct SyncResult {
            let walletId: UUID
            let balance: UInt64
            let errorMessage: String?
        }

        // One BDKWalletService per wallet, all running concurrently.
        let publishers: [AnyPublisher<SyncResult, Never>] = wallets.map { wallet in
            let service = BDKWalletService()
            return Future<SyncResult, Never> { promise in
                Task {
                    do {
                        let balance = try await service.fetchWalletBalance(for: wallet)
                        promise(.success(SyncResult(walletId: wallet.id, balance: balance, errorMessage: nil)))
                    } catch {
                        promise(.success(SyncResult(walletId: wallet.id, balance: 0, errorMessage: error.localizedDescription)))
                    }
                }
            }
            .eraseToAnyPublisher()
        }

        Publishers.MergeMany(publishers)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self else { return }
                if let reason = result.errorMessage {
                    self.uiState.walletSyncStates[result.walletId] = .failed(reason)
                    Log.print.error("[BDK] Background sync failed for wallet \(result.walletId): \(reason)")
                } else {
                    self.uiState.walletSyncStates[result.walletId] = .synced
                    self.uiState.walletBalances[result.walletId] = result.balance
                    // If this is the currently open detail view, also update the detail balance.
                    if self.uiState.selectedWalletId == result.walletId {
                        self.uiState.selectedWalletBalanceSats = result.balance
                    }
                    Log.print.info("[BDK] Background sync completed for wallet \(result.walletId) — balance: \(result.balance) sats")
                }
            }
            .store(in: &syncCancellables)
    }

    // MARK: - Detail-view sync

    /// Syncs a wallet when it is tapped into (detail view):
    /// balance is fetched first (card updates immediately), then transactions.
    @MainActor
    func syncSelectedWallet(_ wallet: Wallet) async {
        uiState.selectedWalletBalanceSats = nil
        uiState.walletSyncStates[wallet.id] = .syncing
        uiState.isLoadingTransactions = true
        uiState.transactions = []

        var encounteredError: String? = nil

        do {
            let balance = try await walletService.fetchWalletBalance(for: wallet)
            uiState.selectedWalletBalanceSats = balance
            uiState.walletBalances[wallet.id] = balance
        } catch {
            encounteredError = error.localizedDescription
            Log.print.error("[BDK] Balance fetch failed for wallet \(wallet.id): \(error.localizedDescription)")
        }

        do {
            uiState.transactions = try await walletService.fetchWalletTransactions(for: wallet)
        } catch {
            encounteredError = encounteredError ?? error.localizedDescription
            Log.print.error("[BDK] Transactions fetch failed for wallet \(wallet.id): \(error.localizedDescription)")
        }

        uiState.isLoadingTransactions = false
        uiState.walletSyncStates[wallet.id] = encounteredError.map { .failed($0) } ?? .synced
    }

    // MARK: - Persistence

    func persistWallet(_ wallet: Wallet) async {
        do {
            try await SwiftDataStorable.shared.save(wallet, id: wallet.id.uuidString)
            Log.print.info("Wallet saved: \(wallet.id.uuidString)")
        } catch {
            Log.print.error("Failed to persist wallet: \(error.localizedDescription)")
        }
    }

    func removePersistedWallet(id: UUID) async {
        do {
            try await SwiftDataStorable.shared.delete(Wallet.self, id: id.uuidString)
            Log.print.info("Wallet deleted: \(id.uuidString)")
        } catch {
            Log.print.error("Failed to delete wallet: \(error.localizedDescription)")
        }
    }
}
