import BitcoinDevKit
import Combine
import Foundation
import WidgetKit

// MARK: - KyotoNodeManager

/// Manages the lifecycle of the Kyoto CBF light client node.
///
/// `CbfBuilder.build(wallet:)` requires a single BDK `Wallet`, so the node
/// is rebuilt per wallet. The manager centralises connection status tracking,
/// shared `UserDefaults` persistence for the home-screen widget, and orderly
/// shutdown on sync-mode switches.
///
/// The node is started at app launch regardless of the active sync mode
/// (`startConnection(with:)`), so the P2P layer is always warm. When the
/// active sync mode is Kyoto, callers should `await waitForConnection()`
/// before beginning wallet syncs.
final class KyotoNodeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = KyotoNodeManager()

    // MARK: - Constants

    /// Shared `UserDefaults` suite for App Group data exchange with the widget.
    static let appGroupId = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String ?? ""
    private static let statusKey = "kyotoConnectionStatus"
    private static let widgetKind = "KyotoStatusWidget"

    // MARK: - Published state

    @Published private(set) var connectionStatus: KyotoNodeConnectionStatus = .disconnected

    // MARK: - Internal state

    /// The currently active CbfClient, if any.
    private var activeClient: CbfClient?

    /// Number of P2P connections the light client maintains.
    private let connectionCount: UInt8 = 2

    // MARK: - Init

    private init() {}

    // MARK: - Connection lifecycle

    /// Starts the Kyoto P2P node using the given app wallet to establish
    /// connectivity. Called at app launch regardless of the active sync mode.
    ///
    /// The first wallet is used to build the CBF components. The node connects
    /// to peers, syncs the wallet, and transitions status from
    /// `.disconnected` → `.connecting` → `.connected`.
    func startConnection(with appWallet: Wallet) {
        guard connectionStatus == .disconnected else {
            Log.print.info("[Kyoto] startConnection skipped — already \(self.connectionStatus.rawValue)")
            return
        }
        guard !appWallet.isAddressWallet else {
            Log.print.warning("[Kyoto] startConnection skipped — address wallets are not supported by CBF")
            return
        }

        Log.print.info("[Kyoto] Starting node connection with wallet '\(appWallet.name)'…")

        Task {
            do {
                let service = KyotoWalletService()
                let (bdkWallet, persister) = try service.loadBDKWallet(for: appWallet)
                try await connectNode(
                    bdkWallet: bdkWallet,
                    persister: persister,
                    walletId: appWallet.id
                )
            } catch {
                Log.print.error("[Kyoto] Initial connection failed: \(error.localizedDescription)")
                updateStatus(.disconnected)
            }
        }
    }

    /// Builds a CBF node, starts it, and waits for the first peer update to
    /// confirm connectivity. The wallet is synced as a side-effect.
    private func connectNode(
        bdkWallet: BitcoinDevKit.Wallet,
        persister: Persister,
        walletId: UUID
    ) async throws {
        let dataDir = KyotoWalletService.cbfDataDirectory(for: walletId)
        try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)

        let components = CbfBuilder()
            .dataDir(dataDir: dataDir)
            .connections(connections: connectionCount)
            .scanType(scanType: .sync)
            .build(wallet: bdkWallet)

        updateStatus(.connecting)
        components.node.run()
        activeClient = components.client

        Log.print.info("[Kyoto] Node started — connecting to peers for wallet \(walletId.uuidString)…")

        let update = try await components.client.update()
        try bdkWallet.applyUpdate(update: update)
        _ = try bdkWallet.persist(persister: persister)

        updateStatus(.connected)
        Log.print.info("[Kyoto] Node connected — initial sync completed for wallet \(walletId.uuidString)")

        // Shut down after confirming connectivity; subsequent syncs rebuild per-wallet.
        shutdownCurrentNode()
    }

    /// Suspends until `connectionStatus` becomes `.connected`.
    /// Returns immediately if already connected.
    func waitForConnection() async {
        let currentStatus = await MainActor.run { connectionStatus }
        if currentStatus == .connected { return }

        Log.print.info("[Kyoto] Waiting for node connection…")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var cancellable: AnyCancellable?
            cancellable = $connectionStatus
                .receive(on: DispatchQueue.main)
                .first(where: { $0 == .connected })
                .sink { _ in
                    continuation.resume()
                    cancellable?.cancel()
                }
        }

        Log.print.info("[Kyoto] Connection confirmed — proceeding")
    }

    // MARK: - Sync a single wallet

    /// Builds a CbfNode for the given wallet, runs it, waits for the update,
    /// applies it, and shuts down the node. Updates `connectionStatus` throughout.
    func syncWallet(
        _ bdkWallet: BitcoinDevKit.Wallet,
        persister: Persister,
        walletId: UUID,
        scanType: ScanType,
        onProgress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        let dataDir = KyotoWalletService.cbfDataDirectory(for: walletId)

        try? FileManager.default.createDirectory(
            atPath: dataDir,
            withIntermediateDirectories: true
        )

        let components = CbfBuilder()
            .dataDir(dataDir: dataDir)
            .connections(connections: connectionCount)
            .scanType(scanType: scanType)
            .build(wallet: bdkWallet)

        updateStatus(.connecting)

        components.node.run()
        activeClient = components.client
        Log.print.info("[Kyoto] Sync started for wallet \(walletId.uuidString) — scanType: \(String(describing: scanType))")

        // Report indeterminate progress — CBF sync doesn't provide granular progress.
        onProgress(nil)

        do {
            let update = try await components.client.update()

            updateStatus(.connected)
            Log.print.info("[Kyoto] Received update for wallet \(walletId.uuidString)")

            try bdkWallet.applyUpdate(update: update)
            let persisted = try bdkWallet.persist(persister: persister)
            Log.print.info("[Kyoto] Wallet \(walletId.uuidString) synced successfully. Persisted: \(persisted)")

            // Signal completion.
            onProgress(1.0)
        } catch {
            updateStatus(.disconnected)
            Log.print.error("[Kyoto] Sync failed for wallet \(walletId.uuidString): \(error.localizedDescription)")
            throw WalletServiceError.unknown("CBF sync failed: \(error.localizedDescription)")
        }

        // Shut down the node for this wallet.
        shutdownCurrentNode()
    }

    // MARK: - Broadcast via CBF

    /// Broadcasts a signed transaction through the Kyoto P2P network.
    func broadcast(
        transaction: BitcoinDevKit.Transaction,
        bdkWallet: BitcoinDevKit.Wallet,
        walletId: UUID
    ) async throws -> Wtxid {
        let dataDir = KyotoWalletService.cbfDataDirectory(for: walletId)
        try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)

        let components = CbfBuilder()
            .dataDir(dataDir: dataDir)
            .connections(connections: connectionCount)
            .scanType(scanType: .sync)
            .build(wallet: bdkWallet)

        Log.print.info("[Kyoto] Broadcasting transaction for wallet \(walletId.uuidString)…")
        components.node.run()
        activeClient = components.client

        defer { shutdownCurrentNode() }

        let wtxid = try await components.client.broadcast(transaction: transaction)
        Log.print.info("[Kyoto] Transaction broadcast successfully for wallet \(walletId.uuidString)")
        return wtxid
    }

    // MARK: - Shutdown

    /// Shuts down the currently running node, if any.
    private func shutdownCurrentNode() {
        guard let client = activeClient else { return }
        do {
            try client.shutdown()
            Log.print.info("[Kyoto] CBF node stopped")
        } catch {
            Log.print.warning("[Kyoto] Failed to shut down CBF node: \(error.localizedDescription)")
        }
        activeClient = nil
    }

    /// Disconnects and resets all state.
    func disconnect() {
        shutdownCurrentNode()
        updateStatus(.disconnected)
        Log.print.info("[Kyoto] Node manager disconnected")
    }

    // MARK: - Status Management

    /// Updates the connection status, persists it for the widget, and triggers
    /// a widget timeline reload.
    private func updateStatus(_ newStatus: KyotoNodeConnectionStatus) {
        Log.print.info("[Kyoto] Status: \(newStatus.rawValue)")
        Task { @MainActor in
            self.connectionStatus = newStatus
        }
        persistStatusForWidget(newStatus)
    }

    /// Writes the current status to the shared `UserDefaults` suite so the
    /// home-screen widget can read it.
    private func persistStatusForWidget(_ status: KyotoNodeConnectionStatus) {
        Task { @MainActor in
            guard let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
            defaults.set(status.rawValue, forKey: Self.statusKey)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }
}
