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

    private let walletService: any WalletServiceProtocol

    /// Per-wallet Combine subscriptions for background syncs.
    /// Keyed by wallet ID so individual syncs can be cancelled on deletion.
    private var syncCancellables = [UUID: AnyCancellable]()

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
        Task {
            await persistWallet(wallet)
            await MainActor.run { syncNewWallet(wallet) }
        }
    }

    func deleteWallet(id: UUID) {
        // Cancel any running sync for this wallet.
        syncCancellables[id]?.cancel()
        syncCancellables.removeValue(forKey: id)

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
        var result = try await walletService.createNewWallet()
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

        var wallet = try await walletService.importWallet(from: source)
        wallet.name = "\(wallet.name) \(uiState.wallets.count + 1)"
        addWallet(wallet)
    }
}

// MARK: - Private async

private extension WalletsViewModel {

    /// Loads persisted wallets from SwiftData on startup, seeds the balance
    /// dictionary from the last persisted `balanceBTC`, then triggers
    /// a background Esplora sync for all wallets via Combine.
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
        syncAllWalletsOnLaunch()
    }

    // MARK: - New wallet sync

    /// Kicks off a background sync for a single newly added wallet.
    @MainActor
    func syncNewWallet(_ wallet: Wallet) {
        uiState.walletSyncStates[wallet.id] = .syncing(progress: nil)

        let service = BDKWalletService()
        syncCancellables[wallet.id] = Future<(UInt64, String?), Never> { promise in
            Task { [weak self] in
                do {
                    let balance = try await service.fetchWalletBalance(for: wallet) { progress in
                        Task { @MainActor in
                            self?.uiState.walletSyncStates[wallet.id] = .syncing(progress: progress)
                        }
                    }
                    promise(.success((balance, nil)))
                } catch {
                    promise(.success((0, error.localizedDescription)))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] balance, errorMessage in
            guard let self else { return }
            if let reason = errorMessage {
                self.uiState.walletSyncStates[wallet.id] = .failed(reason)
                Log.print.error("[BDK] Sync failed for new wallet \(wallet.id): \(reason)")
            } else {
                self.uiState.walletSyncStates[wallet.id] = .synced
                self.uiState.walletBalances[wallet.id] = balance

                if let index = self.uiState.wallets.firstIndex(where: { $0.id == wallet.id }) {
                    let btc = Double(balance) / 100_000_000.0
                    self.uiState.wallets[index].balanceBTC = btc
                    Task { await self.persistWallet(self.uiState.wallets[index]) }
                }
                Log.print.info("[BDK] Sync completed for new wallet \(wallet.id) — balance: \(balance) sats")
            }
        }
    }

    // MARK: - Background sync (Combine)

    /// Creates one `BDKWalletService` instance per wallet and syncs them all
    /// in parallel using `Publishers.MergeMany`. Each wallet's sync state and
    /// balance are updated on the main thread as results arrive.
    /// Progress is forwarded to `walletSyncStates` so the card UI can show it.
    @MainActor
    func syncAllWalletsOnLaunch() {
        // Only sync wallets that are not already being synced.
        let wallets = uiState.wallets.filter { wallet in
            uiState.walletSyncStates[wallet.id]?.isSyncing != true
        }
        guard !wallets.isEmpty else { return }

        // Mark every wallet as syncing immediately so the UI reacts at once.
        for wallet in wallets {
            uiState.walletSyncStates[wallet.id] = .syncing(progress: nil)
        }

        // One BDKWalletService per wallet, all running concurrently.
        // Each wallet gets its own cancellable so it can be cancelled individually.
        for wallet in wallets {
            let service = BDKWalletService()
            syncCancellables[wallet.id] = Future<(UInt64, String?), Never> { promise in
                Task { [weak self] in
                    do {
                        let balance = try await service.fetchWalletBalance(for: wallet) { progress in
                            Task { @MainActor in
                                self?.uiState.walletSyncStates[wallet.id] = .syncing(progress: progress)
                            }
                        }
                        promise(.success((balance, nil)))
                    } catch {
                        promise(.success((0, error.localizedDescription)))
                    }
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance, errorMessage in
                guard let self else { return }
                if let reason = errorMessage {
                    self.uiState.walletSyncStates[wallet.id] = .failed(reason)
                    Log.print.error("[BDK] Background sync failed for wallet \(wallet.id): \(reason)")
                } else {
                    self.uiState.walletSyncStates[wallet.id] = .synced
                    self.uiState.walletBalances[wallet.id] = balance

                    // Persist updated balance into the Wallet model.
                    if let index = self.uiState.wallets.firstIndex(where: { $0.id == wallet.id }) {
                        let btc = Double(balance) / 100_000_000.0
                        self.uiState.wallets[index].balanceBTC = btc
                        Task { await self.persistWallet(self.uiState.wallets[index]) }
                    }

                    // If this is the currently open detail view, also update the detail balance.
                    if self.uiState.selectedWalletId == wallet.id {
                        self.uiState.selectedWalletBalanceSats = balance
                    }
                    Log.print.info("[BDK] Background sync completed for wallet \(wallet.id) — balance: \(balance) sats")
                }
            }
        }
    }

    // MARK: - Detail-view sync

    /// Syncs a wallet once when it is tapped into (detail view), fetching
    /// both balance and transactions in a single network pass.
    ///
    /// The flow preserves the last-known balance and shows cached transactions
    /// immediately while the network sync runs in the background.
    @MainActor
    func syncSelectedWallet(_ wallet: Wallet) async {
        // Keep the last known balance visible — never blank it out.
        uiState.selectedWalletBalanceSats = uiState.walletBalances[wallet.id]

        // Load cached transactions from SwiftData so the user sees something
        // while the network sync runs. Only show the loading spinner if there
        // is no cached data at all.
        let cachedTxs = await loadCachedTransactions(for: wallet.id)
        uiState.transactions = cachedTxs
        uiState.isLoadingTransactions = cachedTxs.isEmpty

        // Skip if this wallet is already being synced (e.g. by the background launch sync).
        // Cached transactions are loaded above so the detail view still has data.
        if uiState.walletSyncStates[wallet.id]?.isSyncing == true {
            Log.print.info("[Sync] Wallet \(wallet.id.uuidString) is already syncing — showing cached data")
            return
        }

        uiState.walletSyncStates[wallet.id] = .syncing(progress: nil)

        do {
            let walletId = wallet.id
            let result = try await walletService.syncWallet(wallet) { [weak self] progress in
                Task { @MainActor in
                    self?.uiState.walletSyncStates[walletId] = .syncing(progress: progress)
                }
            }

            uiState.selectedWalletBalanceSats = result.balance
            uiState.walletBalances[wallet.id] = result.balance
            uiState.transactions = result.transactions
            uiState.walletSyncStates[wallet.id] = .synced

            // Persist updated balance and transactions for next time.
            if let index = uiState.wallets.firstIndex(where: { $0.id == wallet.id }) {
                uiState.wallets[index].balanceBTC = Double(result.balance) / 100_000_000.0
                Task { await persistWallet(uiState.wallets[index]) }
            }
            Task { await persistTransactions(result.transactions, for: wallet.id) }
        } catch {
            uiState.walletSyncStates[wallet.id] = .failed(error.localizedDescription)
            uiState.syncErrorMessage = error.localizedDescription
            Log.print.error("[BDK] Sync failed for wallet \(wallet.id): \(error.localizedDescription)")
        }

        uiState.isLoadingTransactions = false
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

    // MARK: - Transaction persistence

    /// Persists the transaction list for a wallet so it can be shown from cache
    /// before the next network sync completes.
    func persistTransactions(_ transactions: [WalletTransaction], for walletId: UUID) async {
        let list = WalletTransactionList(walletId: walletId, transactions: transactions)
        do {
            try await SwiftDataStorable.shared.save(list, id: "txs_\(walletId.uuidString)")
            Log.print.info("Transactions cached for wallet: \(walletId.uuidString)")
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
            Log.print.info("Cached transactions deleted for wallet: \(walletId.uuidString)")
        } catch {
            Log.print.error("Failed to delete cached transactions: \(error.localizedDescription)")
        }
    }
}
