import Combine
import Foundation

// MARK: - WalletSyncEvent

/// Events published by `WalletSyncManager` for the ViewModel to observe.
///
/// Each event represents a discrete state change in the sync lifecycle.
/// The ViewModel subscribes once and maps every event to the appropriate
/// `uiState` mutation.
enum WalletSyncEvent {

    /// A wallet's sync state changed (queued, syncing, synced, failed).
    case syncStateChanged(walletId: UUID, state: WalletSyncState)

    /// A batch or individual sync completed with a new balance.
    case balanceUpdated(walletId: UUID, balanceSats: UInt64)

    /// A detail-view sync completed with both balance and transactions.
    case selectedWalletSynced(walletId: UUID, balanceSats: UInt64, transactions: [WalletTransaction])

    /// The wallet was recently synced and the cooldown is still active.
    case cooldownActive(walletId: UUID)

    /// The wallet is already being synced by another operation.
    case alreadySyncing(walletId: UUID)

    /// A sync failed with an error message.
    case syncFailed(walletId: UUID, error: String)
}

// MARK: - WalletSyncManagerProtocol

/// Centralises all wallet synchronisation orchestration.
///
/// The manager owns the `WalletServiceProtocol` dependency, tracks running
/// sync tasks, enforces the 60-second cooldown, and ensures sequential
/// Electrum connections. State changes are published via `syncEvents`.
protocol WalletSyncManagerProtocol: AnyObject {

    /// Stream of sync lifecycle events. The ViewModel subscribes to this
    /// to update `uiState` in real-time.
    var syncEvents: AnyPublisher<WalletSyncEvent, Never> { get }

    /// Syncs all wallets sequentially. Wallets already busy are skipped.
    /// Each wallet transitions: idle → queued → syncing → synced/failed.
    func syncAllWallets(_ wallets: [Wallet]) async

    /// Kicks off a background sync for a single newly added wallet.
    func syncNewWallet(_ wallet: Wallet)

    /// Syncs a wallet for the detail view, returning balance and transactions.
    /// Respects the 60-second cooldown and skips if already syncing.
    func syncSelectedWallet(_ wallet: Wallet) async

    /// Forces a full scan on all wallets sequentially, resetting the
    /// incremental sync flag so every wallet is scanned from scratch.
    func fullScanAllWallets(_ wallets: [Wallet]) async

    /// Forces a full scan for the selected wallet, ignoring the cooldown and
    /// bypassing the incremental sync. Used when the user explicitly requests
    /// a complete re-scan from wallet settings.
    func fullScanSelectedWallet(_ wallet: Wallet) async

    /// Cancels any running sync task for the given wallet and clears its
    /// cooldown tracking. Called when a wallet is deleted.
    func cancelSync(for walletId: UUID)
}

// MARK: - WalletSyncManager

/// Production implementation of `WalletSyncManagerProtocol`.
///
/// ### Sequential sync
/// Wallets are synced one at a time to avoid concurrent `ElectrumClient`
/// connections that trigger `CryptoProvider` installation conflicts in the
/// underlying Rust TLS stack (`rustls`).
///
/// ### Cooldown
/// A wallet that was successfully synced within `cooldownInterval` seconds
/// will not be re-synced when entering the detail view. Pull-to-refresh
/// ignores the cooldown.
final class WalletSyncManager: WalletSyncManagerProtocol {

    // MARK: - Published events

    private let eventSubject = PassthroughSubject<WalletSyncEvent, Never>()

    var syncEvents: AnyPublisher<WalletSyncEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    /// Factory that creates a fresh `WalletServiceProtocol` instance.
    /// Used by batch and new-wallet syncs to guarantee a single Electrum
    /// connection per operation.
    private let walletServiceFactory: () -> any WalletServiceProtocol

    /// Shared service instance used for detail-view syncs (balance + txs
    /// in a single pass via `syncWallet`).
    private let detailSyncService: any WalletServiceProtocol

    // MARK: - Internal state

    /// Per-wallet sync tasks, keyed by wallet ID for cancellation on deletion.
    private var syncTasks = [UUID: Task<Void, Never>]()

    /// Tracks when each wallet last completed a successful sync.
    private var lastSyncDates = [UUID: Date]()

    /// Cooldown interval in seconds. Exposed for testability.
    let cooldownInterval: TimeInterval

    // MARK: - Init

    init(
        walletServiceFactory: @escaping () -> any WalletServiceProtocol = { BDKWalletService() },
        detailSyncService: any WalletServiceProtocol = BDKWalletService(),
        cooldownInterval: TimeInterval = 60
    ) {
        self.walletServiceFactory = walletServiceFactory
        self.detailSyncService = detailSyncService
        self.cooldownInterval = cooldownInterval
    }

    // MARK: - syncAllWallets

    @MainActor
    func syncAllWallets(_ wallets: [Wallet]) async {
        guard !wallets.isEmpty else { return }

        // Mark every wallet as queued so the UI shows they are waiting.
        for wallet in wallets {
            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .queued))
        }

        // Single service instance — one Electrum connection at a time.
        let service = walletServiceFactory()

        for wallet in wallets {
            guard !Task.isCancelled else { break }

            // Promote from queued → syncing now that this wallet's turn has arrived.
            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .syncing(progress: nil)))

            do {
                let walletId = wallet.id
                let balance = try await service.fetchWalletBalance(for: wallet) { [weak self] progress in
                    Task { @MainActor in
                        self?.eventSubject.send(.syncStateChanged(walletId: walletId, state: .syncing(progress: progress)))
                    }
                }

                eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .synced))
                eventSubject.send(.balanceUpdated(walletId: wallet.id, balanceSats: balance))
                lastSyncDates[wallet.id] = Date()

                Log.print.info("[BDK] Sync completed for wallet \(wallet.id) — balance: \(balance) sats")
            } catch {
                eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .failed(error.localizedDescription)))
                eventSubject.send(.syncFailed(walletId: wallet.id, error: error.localizedDescription))
                Log.print.error("[BDK] Sync failed for wallet \(wallet.id): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - fullScanAllWallets

    @MainActor
    func fullScanAllWallets(_ wallets: [Wallet]) async {
        guard !wallets.isEmpty else { return }

        for wallet in wallets {
            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .queued))
        }

        let service = walletServiceFactory()

        for wallet in wallets {
            guard !Task.isCancelled else { break }

            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .syncing(progress: nil)))

            do {
                let walletId = wallet.id
                let result = try await service.fullScanWallet(wallet) { [weak self] progress in
                    Task { @MainActor in
                        self?.eventSubject.send(.syncStateChanged(walletId: walletId, state: .syncing(progress: progress)))
                    }
                }

                eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .synced))
                eventSubject.send(.balanceUpdated(walletId: wallet.id, balanceSats: result.balance))
                lastSyncDates[wallet.id] = Date()

                Log.print.info("[BDK] Full scan completed for wallet \(wallet.id) — balance: \(result.balance) sats")
            } catch {
                eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .failed(error.localizedDescription)))
                eventSubject.send(.syncFailed(walletId: wallet.id, error: error.localizedDescription))
                Log.print.error("[BDK] Full scan failed for wallet \(wallet.id): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - syncNewWallet

    @MainActor
    func syncNewWallet(_ wallet: Wallet) {
        eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .syncing(progress: nil)))

        syncTasks[wallet.id] = Task { [weak self] in
            guard let self else { return }
            let service = self.walletServiceFactory()
            do {
                let balance = try await service.fetchWalletBalance(for: wallet) { progress in
                    Task { @MainActor in
                        self.eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .syncing(progress: progress)))
                    }
                }
                await MainActor.run {
                    self.eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .synced))
                    self.eventSubject.send(.balanceUpdated(walletId: wallet.id, balanceSats: balance))
                    self.lastSyncDates[wallet.id] = Date()
                    self.syncTasks.removeValue(forKey: wallet.id)
                    Log.print.info("[BDK] Sync completed for new wallet \(wallet.id) — balance: \(balance) sats")
                }
            } catch {
                await MainActor.run {
                    self.eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .failed(error.localizedDescription)))
                    self.eventSubject.send(.syncFailed(walletId: wallet.id, error: error.localizedDescription))
                    self.syncTasks.removeValue(forKey: wallet.id)
                    Log.print.error("[BDK] Sync failed for new wallet \(wallet.id): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - syncSelectedWallet

    @MainActor
    func syncSelectedWallet(_ wallet: Wallet) async {
        // Check if already syncing.
        if syncTasks[wallet.id] != nil {
            eventSubject.send(.alreadySyncing(walletId: wallet.id))
            Log.print.info("[Sync] Wallet \(wallet.id.uuidString) is already syncing")
            return
        }

        // Check cooldown.
        if let lastSync = lastSyncDates[wallet.id],
           Date().timeIntervalSince(lastSync) < cooldownInterval {
            eventSubject.send(.cooldownActive(walletId: wallet.id))
            Log.print.info("[Sync] Wallet \(wallet.id.uuidString) synced \(Int(Date().timeIntervalSince(lastSync)))s ago — cooldown active")
            return
        }

        eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .syncing(progress: nil)))

        do {
            let walletId = wallet.id
            let result = try await detailSyncService.syncWallet(wallet) { [weak self] progress in
                Task { @MainActor in
                    self?.eventSubject.send(.syncStateChanged(walletId: walletId, state: .syncing(progress: progress)))
                }
            }

            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .synced))
            eventSubject.send(.selectedWalletSynced(walletId: wallet.id, balanceSats: result.balance, transactions: result.transactions))
            lastSyncDates[wallet.id] = Date()

            Log.print.info("[BDK] Detail sync completed for wallet \(wallet.id) — balance: \(result.balance) sats")
        } catch {
            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .failed(error.localizedDescription)))
            eventSubject.send(.syncFailed(walletId: wallet.id, error: error.localizedDescription))
            Log.print.error("[BDK] Detail sync failed for wallet \(wallet.id): \(error.localizedDescription)")
        }
    }

    // MARK: - fullScanSelectedWallet

    @MainActor
    func fullScanSelectedWallet(_ wallet: Wallet) async {
        // Cancel any existing sync for this wallet before starting a full scan.
        syncTasks[wallet.id]?.cancel()
        syncTasks.removeValue(forKey: wallet.id)

        eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .syncing(progress: nil)))

        do {
            let walletId = wallet.id
            let result = try await detailSyncService.fullScanWallet(wallet) { [weak self] progress in
                Task { @MainActor in
                    self?.eventSubject.send(.syncStateChanged(walletId: walletId, state: .syncing(progress: progress)))
                }
            }

            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .synced))
            eventSubject.send(.selectedWalletSynced(walletId: wallet.id, balanceSats: result.balance, transactions: result.transactions))
            lastSyncDates[wallet.id] = Date()

            Log.print.info("[BDK] Full scan completed for wallet \(wallet.id) — balance: \(result.balance) sats")
        } catch {
            eventSubject.send(.syncStateChanged(walletId: wallet.id, state: .failed(error.localizedDescription)))
            eventSubject.send(.syncFailed(walletId: wallet.id, error: error.localizedDescription))
            Log.print.error("[BDK] Full scan failed for wallet \(wallet.id): \(error.localizedDescription)")
        }
    }

    // MARK: - cancelSync

    func cancelSync(for walletId: UUID) {
        syncTasks[walletId]?.cancel()
        syncTasks.removeValue(forKey: walletId)
        lastSyncDates.removeValue(forKey: walletId)
    }
}
