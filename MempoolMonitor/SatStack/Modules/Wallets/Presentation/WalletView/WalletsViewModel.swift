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

    /// Current balance in BTC. Updated and persisted after each successful sync.
    var balanceBTC: Double

    /// BIP-39 mnemonic phrase (space-separated words). Nil for watch-only wallets.
    let mnemonicPhrase: String?

    /// Original import descriptor (xpub or Bitcoin address) for watch-only wallets.
    /// Used for duplicate detection. Nil for seed-based wallets.
    let descriptor: String?

    init(id: UUID, name: String, theme: WalletTheme, balanceBTC: Double, mnemonicPhrase: String? = nil, descriptor: String? = nil) {
        self.id = id
        self.name = name
        self.theme = theme
        self.balanceBTC = balanceBTC
        self.mnemonicPhrase = mnemonicPhrase
        self.descriptor = descriptor
    }
}

// MARK: - WalletTransaction model

/// A single Bitcoin transaction associated with a wallet.
struct WalletTransaction: Identifiable, Codable {

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
        return "\(address.prefix(6))…\(address.suffix(6))"
    }

    /// Human-readable relative date (e.g. "2 hours ago").
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// Whether this transaction is incoming (received) from the wallet's perspective.
    var isReceived: Bool { valueBTC >= 0 }

    /// Formatted BTC value with sign prefix (e.g. "+₿ 0.00210" or "−₿ 0.00067").
    var formattedValue: String {
        let sign = valueBTC >= 0 ? "+" : ""
        return "\(sign)₿ \(String(format: "%.5f", valueBTC))"
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

// MARK: - WalletTransactionList (persistence wrapper)

/// Wrapper for persisting a wallet's transaction list to SwiftData.
struct WalletTransactionList: Codable {
    let walletId: UUID
    let transactions: [WalletTransaction]
}

// MARK: - WalletSyncState

/// Lifecycle state of an on-chain wallet synchronisation.
enum WalletSyncState: Equatable {

    /// Sync has not been triggered yet for this session.
    case idle

    /// Waiting in the sequential sync queue — another wallet is syncing first.
    case queued

    /// A full scan or incremental sync is currently running.
    /// `progress` is `nil` for indeterminate (full scan) or `0.0–1.0` for incremental sync.
    case syncing(progress: Double?)

    /// The last sync completed successfully.
    case synced

    /// The last sync failed with the given reason.
    case failed(String)

    /// Convenience check for any syncing variant.
    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }

    /// True when the wallet is either queued or actively syncing.
    var isBusy: Bool {
        switch self {
        case .queued, .syncing: return true
        default: return false
        }
    }
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

    /// Detects the input type (seed phrase, xpub, or Bitcoin address), validates
    /// it with the wallet service, checks for duplicates, and persists — all in one step.
    func importWallet(input: String) async throws

    /// Syncs all wallets sequentially. Called on first load.
    func syncAllWallets() async

    /// Forces a full scan on all wallets sequentially. Called on pull-to-refresh.
    func fullScanAllWallets() async

    /// Forces a full re-scan of the currently selected wallet, bypassing
    /// the incremental sync and cooldown.
    func forceFullScan()
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

    /// Non-nil when a sync error should be shown to the user.
    var syncErrorMessage: String? = nil

    /// Controls whether the sync-error alert is presented.
    var isPresentingSyncError: Bool {
        get { syncErrorMessage != nil }
        set { if !newValue { syncErrorMessage = nil } }
    }
}

// MARK: - WalletsViewModel

final class WalletsViewModel: WalletsViewModelProtocol {

    @Published var uiState: WalletsUiState = .init()

    /// Sync orchestration — owns the `WalletServiceProtocol`, task tracking,
    /// cooldown logic, and sequential Electrum connection management.
    private let syncManager: any WalletSyncManagerProtocol

    /// Service used exclusively for wallet lifecycle operations (create / import).
    /// Sync operations are delegated to the `syncManager`.
    private let walletLifecycleService: any WalletServiceProtocol

    /// Combine subscriptions for sync event observation.
    private var cancellables = Set<AnyCancellable>()

    init(
        syncManager: any WalletSyncManagerProtocol = WalletSyncManager(),
        walletLifecycleService: any WalletServiceProtocol = BDKWalletService()
    ) {
        self.syncManager = syncManager
        self.walletLifecycleService = walletLifecycleService
        subscribeSyncEvents()
        Task { @MainActor in await self.loadWallets() }
    }

    // MARK: - Sync event subscription

    private func subscribeSyncEvents() {
        syncManager.syncEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handleSyncEvent(event)
                }
            }
            .store(in: &cancellables)
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

        // Show last known balance immediately.
        uiState.selectedWalletBalanceSats = uiState.walletBalances[wallet.id]

        Task { @MainActor in
            // Load cached transactions so the user sees something while the
            // network sync runs. Only show the loading spinner if there is
            // no cached data at all.
            let cachedTxs = await self.loadCachedTransactions(for: wallet.id)
            self.uiState.transactions = cachedTxs
            self.uiState.isLoadingTransactions = cachedTxs.isEmpty

            // If the wallet is already queued or syncing (e.g. from a batch
            // full scan), let the batch handle it — don't start a separate sync.
            let currentState = self.uiState.walletSyncStates[wallet.id]
            guard currentState?.isBusy != true else { return }

            // Delegate the actual sync to the manager.
            await self.syncManager.syncSelectedWallet(wallet)
        }
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
        Task {
            await persistWallet(wallet)
            await MainActor.run { self.syncManager.syncNewWallet(wallet) }
        }
    }

    func deleteWallet(id: UUID) {
        syncManager.cancelSync(for: id)

        uiState.wallets.removeAll { $0.id == id }
        uiState.selectedWalletId = nil
        uiState.transactions = []
        uiState.isPresentingWalletSettings = false
        uiState.walletSyncStates.removeValue(forKey: id)
        uiState.walletBalances.removeValue(forKey: id)
        Task {
            await removePersistedWallet(id: id)
            await removePersistedTransactions(for: id)
        }
    }

    @MainActor
    func createWallet() async throws -> WalletCreationResult {
        var result = try await walletLifecycleService.createNewWallet()
        result.wallet.name = "My Wallet \(uiState.wallets.count + 1)"
        return result
    }

    @MainActor
    func importWallet(input: String) async throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        let source: WalletImportSource
        if trimmed.hasPrefix("xpub") || trimmed.hasPrefix("ypub") || trimmed.hasPrefix("zpub") {
            guard !uiState.wallets.contains(where: { $0.descriptor == trimmed }) else {
                throw WalletServiceError.invalidImportSource("This xpub is already imported.")
            }
            source = .xpub(trimmed)
        } else if trimmed.hasPrefix("bc1") || trimmed.hasPrefix("1") || trimmed.hasPrefix("3") {
            guard !uiState.wallets.contains(where: { $0.descriptor == trimmed }) else {
                throw WalletServiceError.invalidImportSource("This address is already imported.")
            }
            source = .address(trimmed)
        } else {
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let phrase = words.joined(separator: " ")
            guard !uiState.wallets.contains(where: { $0.mnemonicPhrase == phrase }) else {
                throw WalletServiceError.invalidImportSource("This seed phrase is already imported.")
            }
            source = .seedPhrase(words)
        }

        var wallet = try await walletLifecycleService.importWallet(from: source)
        wallet.name = "\(wallet.name) \(uiState.wallets.count + 1)"
        addWallet(wallet)
    }
}

// MARK: - Batch sync (protocol conformance)

extension WalletsViewModel {

    /// Filters busy wallets and delegates to the sync manager.
    @MainActor
    func syncAllWallets() async {
        let walletsToSync = uiState.wallets.filter { wallet in
            uiState.walletSyncStates[wallet.id]?.isBusy != true
        }
        await syncManager.syncAllWallets(walletsToSync)
    }

    /// Forces a full scan on all non-busy wallets. Called on pull-to-refresh.
    @MainActor
    func fullScanAllWallets() async {
        let walletsToSync = uiState.wallets.filter { wallet in
            uiState.walletSyncStates[wallet.id]?.isBusy != true
        }
        await syncManager.fullScanAllWallets(walletsToSync)
    }

    /// Forces a full re-scan of the currently selected wallet.
    /// Dismisses settings, resets the transaction loading state, and delegates
    /// to the sync manager for a complete script-pubkey scan.
    func forceFullScan() {
        guard let id = uiState.selectedWalletId,
              let wallet = uiState.wallets.first(where: { $0.id == id }) else { return }

        uiState.isPresentingWalletSettings = false
        uiState.isLoadingTransactions = true

        Task { @MainActor in
            await syncManager.fullScanSelectedWallet(wallet)
        }
    }
}

// MARK: - Sync event handling

private extension WalletsViewModel {

    /// Maps each `WalletSyncEvent` to the appropriate `uiState` mutation.
    @MainActor
    func handleSyncEvent(_ event: WalletSyncEvent) {
        switch event {
        case .syncStateChanged(let walletId, let state):
            // Ignore events for wallets that were deleted while syncing.
            guard uiState.wallets.contains(where: { $0.id == walletId }) else { return }
            uiState.walletSyncStates[walletId] = state

        case .balanceUpdated(let walletId, let balanceSats):
            guard uiState.wallets.contains(where: { $0.id == walletId }) else { return }
            uiState.walletBalances[walletId] = balanceSats

            if let index = uiState.wallets.firstIndex(where: { $0.id == walletId }) {
                let btc = Double(balanceSats) / 100_000_000.0
                uiState.wallets[index].balanceBTC = btc
                Task { await self.persistWallet(self.uiState.wallets[index]) }
            }

            if uiState.selectedWalletId == walletId {
                uiState.selectedWalletBalanceSats = balanceSats
            }

        case .selectedWalletSynced(let walletId, let balanceSats, let transactions):
            guard uiState.wallets.contains(where: { $0.id == walletId }) else { return }
            uiState.selectedWalletBalanceSats = balanceSats
            uiState.walletBalances[walletId] = balanceSats
            uiState.transactions = transactions
            uiState.isLoadingTransactions = false

            if let index = uiState.wallets.firstIndex(where: { $0.id == walletId }) {
                uiState.wallets[index].balanceBTC = Double(balanceSats) / 100_000_000.0
                Task { await self.persistWallet(self.uiState.wallets[index]) }
            }
            Task { await self.persistTransactions(transactions, for: walletId) }

        case .cooldownActive:
            uiState.isLoadingTransactions = false

        case .alreadySyncing:
            // No-op: cached data was already loaded by selectWallet().
            break

        case .syncFailed(let walletId, let error):
            if uiState.selectedWalletId == walletId {
                uiState.syncErrorMessage = error
                uiState.isLoadingTransactions = false
            }
        }
    }
}

// MARK: - Private async (persistence + loading)

private extension WalletsViewModel {

    /// Loads persisted wallets from SwiftData on startup, seeds the balance
    /// dictionary from the last persisted `balanceBTC`, then triggers
    /// a background sync for all wallets.
    @MainActor
    func loadWallets() async {
        uiState.isLoadingWallets = true
        do {
            let stored: [Wallet] = try await SwiftDataStorable.shared.fetchAll(Wallet.self)
            uiState.wallets = stored

            // Seed per-wallet balances from the last persisted value so the UI
            // shows something immediately, even before the network sync completes.
            for wallet in stored where wallet.balanceBTC > 0 {
                let sats = UInt64(wallet.balanceBTC * 100_000_000)
                uiState.walletBalances[wallet.id] = sats
            }
        } catch {
            Log.print.error("Failed to load wallets: \(error.localizedDescription)")
            uiState.wallets = []
        }
        uiState.isLoadingWallets = false

        // Kick off background sync for every loaded wallet.
        await syncAllWallets()
    }

    // MARK: - Persistence

    func persistWallet(_ wallet: Wallet) async {
        do {
            try await SwiftDataStorable.shared.save(wallet, id: wallet.id.uuidString)
            Log.print.info("Wallet saved: '\(wallet.name)'")
        } catch {
            Log.print.error("Failed to persist wallet: \(error.localizedDescription)")
        }
    }

    func removePersistedWallet(id: UUID) async {
        do {
            try await SwiftDataStorable.shared.delete(Wallet.self, id: id.uuidString)
            Log.print.info("Wallet deleted: \(id)")
        } catch {
            Log.print.error("Failed to delete wallet: \(error.localizedDescription)")
        }
    }

    // MARK: - Transaction persistence

    /// Persists the transaction list for a wallet so it can be shown from cache
    /// before the next network sync completes.
    func persistTransactions(_ transactions: [WalletTransaction], for walletId: UUID) async {
        let list = WalletTransactionList(walletId: walletId, transactions: transactions)
        do {
            try await SwiftDataStorable.shared.save(list, id: "txs_\(walletId.uuidString)")
            let walletName = uiState.wallets.first(where: { $0.id == walletId })?.name ?? walletId.uuidString
            Log.print.info("Transactions cached for wallet: '\(walletName)'")
        } catch {
            Log.print.error("Failed to cache transactions: \(error.localizedDescription)")
        }
    }

    /// Loads previously cached transactions for a wallet from SwiftData.
    func loadCachedTransactions(for walletId: UUID) async -> [WalletTransaction] {
        do {
            let list: WalletTransactionList? = try await SwiftDataStorable.shared.fetch(
                WalletTransactionList.self,
                id: "txs_\(walletId.uuidString)"
            )
            return list?.transactions ?? []
        } catch {
            Log.print.error("Failed to load cached transactions: \(error.localizedDescription)")
            return []
        }
    }

    /// Removes cached transactions for a deleted wallet.
    func removePersistedTransactions(for walletId: UUID) async {
        do {
            try await SwiftDataStorable.shared.delete(
                WalletTransactionList.self,
                id: "txs_\(walletId.uuidString)"
            )
            Log.print.info("Cached transactions deleted for wallet: \(walletId)")
        } catch {
            Log.print.error("Failed to delete cached transactions: \(error.localizedDescription)")
        }
    }
}
