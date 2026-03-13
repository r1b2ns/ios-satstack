import Combine
import Foundation

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

    /// An incremental sync is currently running.
    /// `progress` is `nil` for indeterminate or `0.0–1.0` for determinate progress.
    case syncing(progress: Double?)

    /// A full BIP-84 scan is running; `count` is the number of scripts inspected so far.
    case fullScanning(count: UInt64)

    /// The last sync completed successfully.
    case synced

    /// The last sync failed with the given reason.
    case failed(String)

    /// Convenience check for any syncing variant.
    var isSyncing: Bool {
        switch self {
        case .syncing, .fullScanning: return true
        default: return false
        }
    }

    /// True when the wallet is either queued or actively syncing/scanning.
    var isBusy: Bool {
        switch self {
        case .queued, .syncing, .fullScanning: return true
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

    /// Derives the next receive address for the selected wallet and presents
    /// the receive sheet with a QR code.
    func showReceiveAddress()

    /// Presents the send-bitcoin sheet for the currently selected wallet.
    func showSendSheet()
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

    /// Controls whether the receive-address sheet is presented.
    var isPresentingReceiveSheet: Bool = false

    /// The derived receive address for the selected wallet, or `nil` while loading.
    var receiveAddress: String? = nil

    /// Controls whether the send-bitcoin sheet is presented.
    var isPresentingSendSheet: Bool = false

    /// Total wallet balance in BTC, computed by summing all persisted wallets.
    /// `nil` until the first successful fetch from SwiftData.
    var totalWalletBalanceBTC: Double? = nil

    /// Total wallet balance in satoshis, computed by summing all per-wallet balances.
    /// `nil` until the first successful fetch from SwiftData.
    var totalWalletBalanceSats: UInt64? = nil

    /// Non-nil when a sync error should be shown to the user.
    var syncErrorMessage: String? = nil

    /// Controls whether the sync-error alert is presented.
    var isPresentingSyncError: Bool {
        get { syncErrorMessage != nil }
        set { if !newValue { syncErrorMessage = nil } }
    }

    /// Per-wallet Kyoto P2P connection status. `true` when the CBF client
    /// reported a successful connection for the given wallet.
    var kyotoConnectionStatuses: [UUID: Bool] = [:]
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

    /// Persistent storage backend for non-sensitive wallet data and cached transactions.
    private let swiftDataStorage: any PersistentStorable

    /// Secure key-value storage for sensitive fields (`mnemonicPhrase`, `descriptor`).
    private let keychainStorage: KeyStorable

    /// Combine subscriptions for sync event observation.
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    init(
        syncManager: any WalletSyncManagerProtocol = WalletSyncManager(),
        walletLifecycleService: any WalletServiceProtocol = BDKWalletService(),
        swiftDataStorage: (any PersistentStorable)? = nil,
        keychainStorage: KeyStorable = KeychainStorable.shared
    ) {
        self.syncManager = syncManager
        self.walletLifecycleService = walletLifecycleService
        // Resolve inside the @MainActor init body so SwiftDataStorable.shared
        // (which is @MainActor-isolated) is accessed in the correct context.
        self.swiftDataStorage = swiftDataStorage ?? SwiftDataStorable.shared
        self.keychainStorage = keychainStorage
        subscribeSyncEvents()
        subscribeKyotoConnectionEvents()
        Task { @MainActor in await self.loadWallets() }
        Task { @MainActor in await self.fetchWalletBalance() }
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

    // MARK: - Kyoto connection event subscription

    private func subscribeKyotoConnectionEvents() {
        NotificationCenter.default.publisher(for: .cbfClientConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let walletIdString = notification.userInfo?["walletId"] as? String,
                      let walletId = UUID(uuidString: walletIdString) else { return }
                self?.uiState.kyotoConnectionStatuses[walletId] = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cbfClientDisconnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let walletIdString = notification.userInfo?["walletId"] as? String,
                   let walletId = UUID(uuidString: walletIdString) {
                    self?.uiState.kyotoConnectionStatuses[walletId] = false
                } else {
                    // Cleanup calls (stopBackgroundMonitoring / cancelAllMonitoring)
                    // post without walletId — reset all statuses.
                    self?.uiState.kyotoConnectionStatuses.keys.forEach { key in
                        self?.uiState.kyotoConnectionStatuses[key] = false
                    }
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

            // Start the Live Activity for this single-wallet sync.
            BackgroundSyncManager.shared.beginSync(
                totalWallets: 1,
                walletNames: [wallet.id: wallet.name],
                syncEvents: self.syncManager.syncEvents
            )

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
        result.wallet.name = String(localized: "My Wallet \(uiState.wallets.count + 1)")
        return result
    }

    @MainActor
    func importWallet(input: String) async throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        let source: WalletImportSource
        let xpubPrefixes = ["xpub", "ypub", "zpub", "tpub", "upub", "vpub"]
        let addressPrefixes = ["bc1", "tb1", "1", "3"]

        if xpubPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            guard !uiState.wallets.contains(where: { $0.descriptor == trimmed }) else {
                throw WalletServiceError.invalidImportSource(String(localized: "This xpub is already imported."))
            }
            source = .xpub(trimmed)
        } else if addressPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            guard !uiState.wallets.contains(where: { $0.descriptor == trimmed }) else {
                throw WalletServiceError.invalidImportSource(String(localized: "This address is already imported."))
            }
            source = .address(trimmed)
        } else {
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let phrase = words.joined(separator: " ")
            guard !uiState.wallets.contains(where: { $0.mnemonicPhrase == phrase }) else {
                throw WalletServiceError.invalidImportSource(String(localized: "This seed phrase is already imported."))
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
        guard !walletsToSync.isEmpty else { return }

        let walletNames = Dictionary(uniqueKeysWithValues: walletsToSync.map { ($0.id, $0.name) })
        BackgroundSyncManager.shared.beginSync(
            totalWallets: walletsToSync.count,
            walletNames: walletNames,
            syncEvents: syncManager.syncEvents
        )

        let manager = syncManager
        Task { @MainActor in
            await manager.syncAllWallets(walletsToSync)
        }
    }

    /// Forces a full scan on all non-busy wallets. Called on pull-to-refresh.
    ///
    /// The sync is launched in a detached `Task` so it is not tied to
    /// SwiftUI's `.refreshable` cooperative task, which can be cancelled
    /// when the view re-renders after the first wallet finishes.
    @MainActor
    func fullScanAllWallets() async {
        let walletsToSync = uiState.wallets.filter { wallet in
            uiState.walletSyncStates[wallet.id]?.isBusy != true
        }
        guard !walletsToSync.isEmpty else { return }

        let walletNames = Dictionary(uniqueKeysWithValues: walletsToSync.map { ($0.id, $0.name) })
        BackgroundSyncManager.shared.beginSync(
            totalWallets: walletsToSync.count,
            walletNames: walletNames,
            syncEvents: syncManager.syncEvents
        )

        let manager = syncManager
        Task { @MainActor in
            await manager.fullScanAllWallets(walletsToSync)
        }
    }

    /// Forces a full re-scan of the currently selected wallet.
    /// Dismisses settings, resets the transaction loading state, and delegates
    /// to the sync manager for a complete script-pubkey scan.
    func forceFullScan() {
        guard let id = uiState.selectedWalletId,
              let wallet = uiState.wallets.first(where: { $0.id == id }) else { return }

        uiState.isPresentingWalletSettings = false
        uiState.isLoadingTransactions = true

        BackgroundSyncManager.shared.beginSync(
            totalWallets: 1,
            walletNames: [wallet.id: wallet.name],
            syncEvents: syncManager.syncEvents
        )

        Task { @MainActor in
            await syncManager.fullScanSelectedWallet(wallet)
        }
    }

    /// Derives the next receive address and presents the receive sheet.
    /// For address-only watch wallets, shows the wallet's own descriptor address directly.
    func showReceiveAddress() {
        guard let id = uiState.selectedWalletId,
              let wallet = uiState.wallets.first(where: { $0.id == id }) else { return }

        uiState.receiveAddress = nil
        uiState.isPresentingReceiveSheet = true

        // Address wallets already have the receive address as their descriptor.
        if wallet.isAddressWallet, let address = wallet.descriptor {
            uiState.receiveAddress = address
            return
        }

        Task { @MainActor in
            do {
                let address = try await walletLifecycleService.getReceiveAddress(for: wallet)
                self.uiState.receiveAddress = address
            } catch {
                Log.print.error("Failed to get receive address: \(error.localizedDescription)")
            }
        }
    }

    /// Presents the send-bitcoin sheet for the currently selected wallet.
    func showSendSheet() {
        guard uiState.selectedWalletId != nil else { return }
        uiState.isPresentingSendSheet = true
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

            uiState.totalWalletBalanceBTC  = uiState.walletBalances.values
                .reduce(0.0) { $0 + Double($1) / 100_000_000.0 }
            uiState.totalWalletBalanceSats = uiState.walletBalances.values.reduce(0, +)

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

            uiState.totalWalletBalanceBTC  = uiState.walletBalances.values
                .reduce(0.0) { $0 + Double($1) / 100_000_000.0 }
            uiState.totalWalletBalanceSats = uiState.walletBalances.values.reduce(0, +)

        case .transactionsUpdated(let walletId, let transactions):
            guard uiState.wallets.contains(where: { $0.id == walletId }) else { return }
            // Cache transactions so they are available when the user opens this wallet.
            Task { await self.persistTransactions(transactions, for: walletId) }
            // If this wallet is currently selected, refresh the UI immediately.
            if uiState.selectedWalletId == walletId {
                uiState.transactions = transactions
                uiState.isLoadingTransactions = false
            }

        case .cooldownActive:
            uiState.isLoadingTransactions = false

        case .alreadySyncing:
            // No-op: cached data was already loaded by selectWallet().
            break

        case .syncFailed(let walletId, let error):
            guard uiState.wallets.contains(where: { $0.id == walletId }) else { return }
            uiState.syncErrorMessage = error
            if uiState.selectedWalletId == walletId {
                uiState.isLoadingTransactions = false
            }
        }
    }
}

// MARK: - Private async (persistence + loading)

private extension WalletsViewModel {

    // MARK: - Wallet balance fetch

    /// Loads all persisted wallets from SwiftData and sums their `balanceBTC`.
    @MainActor
    func fetchWalletBalance() async {
        do {
            let wallets: [Wallet] = try await swiftDataStorage.fetchAll(Wallet.self)
            let total = wallets.reduce(0.0) { $0 + $1.balanceBTC }
            uiState.totalWalletBalanceBTC  = total
            uiState.totalWalletBalanceSats = wallets.reduce(0) { $0 + UInt64($1.balanceBTC * 100_000_000) }
        } catch {
            Log.print.error("Wallet balance fetch failed: \(error.localizedDescription)")
        }
    }

    /// Loads persisted wallets from SwiftData on startup, seeds the balance
    /// dictionary from the last persisted `balanceBTC`, then triggers
    /// a background sync for all wallets.
    @MainActor
    func loadWallets() async {
        uiState.isLoadingWallets = true
        do {
            var stored: [Wallet] = try await swiftDataStorage.fetchAll(Wallet.self)

            // Re-hydrate sensitive fields from the Keychain.
            // They are intentionally excluded from SwiftData via Wallet.CodingKeys.
            for index in stored.indices {
                let id = stored[index].id
                stored[index].mnemonicPhrase = keychainStorage.string(forKey: mnemonicKey(for: id))
                stored[index].descriptor     = keychainStorage.string(forKey: descriptorKey(for: id))
            }

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
            // SwiftData stores only non-sensitive fields (CodingKeys excludes mnemonic/descriptor).
            try await swiftDataStorage.save(wallet, id: wallet.id.uuidString)

            // Sensitive fields are stored exclusively in the iOS Keychain.
            if let phrase = wallet.mnemonicPhrase {
                keychainStorage.set(phrase, forKey: mnemonicKey(for: wallet.id))
            }
            if let descriptor = wallet.descriptor {
                keychainStorage.set(descriptor, forKey: descriptorKey(for: wallet.id))
            }

            Log.print.info("Wallet saved: '\(wallet.name)'")
        } catch {
            Log.print.error("Failed to persist wallet: \(error.localizedDescription)")
        }
    }

    func removePersistedWallet(id: UUID) async {
        do {
            try await swiftDataStorage.delete(Wallet.self, id: id.uuidString)

            // Remove sensitive fields from the Keychain along with the wallet record.
            keychainStorage.removeObject(forKey: mnemonicKey(for: id))
            keychainStorage.removeObject(forKey: descriptorKey(for: id))

            Log.print.info("Wallet deleted: \(id)")
        } catch {
            Log.print.error("Failed to delete wallet: \(error.localizedDescription)")
        }
    }

    // MARK: - Keychain key helpers

    /// Keychain key for the mnemonic phrase of a given wallet.
    private func mnemonicKey(for id: UUID) -> String { "wallet.mnemonic.\(id.uuidString)" }

    /// Keychain key for the descriptor (xpub / address) of a given wallet.
    private func descriptorKey(for id: UUID) -> String { "wallet.descriptor.\(id.uuidString)" }

    // MARK: - Transaction persistence

    /// Persists the transaction list for a wallet so it can be shown from cache
    /// before the next network sync completes.
    func persistTransactions(_ transactions: [WalletTransaction], for walletId: UUID) async {
        let list = WalletTransactionList(walletId: walletId, transactions: transactions)
        do {
            try await swiftDataStorage.save(list, id: "txs_\(walletId.uuidString)")
            let walletName = uiState.wallets.first(where: { $0.id == walletId })?.name ?? walletId.uuidString
            Log.print.info("Transactions cached for wallet: '\(walletName)'")
        } catch {
            Log.print.error("Failed to cache transactions: \(error.localizedDescription)")
        }
    }

    /// Loads previously cached transactions for a wallet from SwiftData.
    func loadCachedTransactions(for walletId: UUID) async -> [WalletTransaction] {
        do {
            let list: WalletTransactionList? = try await swiftDataStorage.fetch(
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
            try await swiftDataStorage.delete(
                WalletTransactionList.self,
                id: "txs_\(walletId.uuidString)"
            )
            Log.print.info("Cached transactions deleted for wallet: \(walletId)")
        } catch {
            Log.print.error("Failed to delete cached transactions: \(error.localizedDescription)")
        }
    }
}
