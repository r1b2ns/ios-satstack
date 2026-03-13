import ActivityKit
import BackgroundTasks
import Combine
import UIKit

/// Manages the background processing task and Live Activity for wallet synchronisation.
///
/// When a batch or individual sync starts, `beginSync` is called to:
/// 1. Start a local-only Live Activity (no push) showing progress
/// 2. Request extended background execution via `UIApplication.beginBackgroundTask`
/// 3. Subscribe to `WalletSyncManager.syncEvents` and map them to Live Activity updates
///
/// The manager is a singleton, consistent with `LiveActivityManager` and `APNsTokenManager`.
final class BackgroundSyncManager {

    // MARK: - Singleton

    static let shared = BackgroundSyncManager()

    // MARK: - Constants

    static let taskIdentifier = "space.underground.satstack.wallet-sync"

    // MARK: - State

    private var currentActivity: Activity<WalletSyncActivityAttributes>?
    private var cancellables = Set<AnyCancellable>()
    private var appLifecycleCancellables = Set<AnyCancellable>()
    private var walletNames = [UUID: String]()
    private var completedWalletCount = 0
    private var totalWalletCount = 0
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var lastProgressUpdate = Date.distantPast
    private var isSyncing = false
    private var isKyotoMode = false

    // MARK: - Init

    private init() {
        observeAppLifecycle()
    }

    // MARK: - BGTaskScheduler Registration

    /// Registers the background processing task. Call once from `AppDelegate.didFinishLaunchingWithOptions`.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleBackgroundTask(processingTask)
        }
        Log.print.info("[BGSync] Background task registered: \(Self.taskIdentifier)")
    }

    // MARK: - Begin Sync

    /// Starts a Live Activity and requests background execution time.
    ///
    /// - Parameters:
    ///   - totalWallets: Number of wallets in this sync batch.
    ///   - walletNames: Mapping from wallet ID to display name.
    ///   - syncEvents: Publisher from `WalletSyncManager.syncEvents`.
    func beginSync(
        totalWallets: Int,
        walletNames: [UUID: String],
        syncEvents: AnyPublisher<WalletSyncEvent, Never>,
        isKyotoMode: Bool = false
    ) {
        // If a Live Activity is already running, just re-subscribe to the new
        // event stream without creating a duplicate activity.
        if currentActivity != nil {
            subscribeSyncEvents(syncEvents)
            Log.print.info("[BGSync] Reused existing Live Activity for new sync")
            return
        }

        self.totalWalletCount = totalWallets
        self.completedWalletCount = 0
        self.walletNames = walletNames
        self.lastProgressUpdate = .distantPast
        self.isKyotoMode = isKyotoMode

        isSyncing = true
        startLiveActivity(totalWallets: totalWallets)
        scheduleBackgroundTask()
        subscribeSyncEvents(syncEvents)

        Log.print.info("[BGSync] Sync session started — \(totalWallets) wallet(s)")
    }

    // MARK: - End Sync

    /// Ends the sync session: updates the Live Activity to "completed" and cleans up.
    private func endSync() {
        isSyncing = false
        unsubscribeSyncEvents()
        endLiveActivity(status: .completed, errorMessage: nil)
        endBackgroundExecution()
        completedWalletCount = 0
        totalWalletCount = 0
        walletNames.removeAll()

        Log.print.info("[BGSync] Sync session ended")
    }

    // MARK: - Live Activity

    private func startLiveActivity(totalWallets: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.print.warning("[BGSync] Live Activities disabled by user")
            return
        }

        // End any existing sync activity before starting a new one.
        if let existing = currentActivity {
            Task {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = WalletSyncActivityAttributes(startedAt: Date())
        let initialState = WalletSyncActivityAttributes.ContentState(
            status: .syncing,
            progress: 0.0,
            fullScanScriptCount: nil,
            currentWalletName: nil,
            completedWallets: 0,
            totalWallets: totalWallets,
            errorMessage: nil,
            isKyotoMode: isKyotoMode
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            Log.print.info("[BGSync] Live Activity started — id: \(activity.id)")
        } catch {
            Log.print.error("[BGSync] Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity(with state: WalletSyncActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity(status: WalletSyncActivityStatus, errorMessage: String?) {
        guard let activity = currentActivity else { return }

        let finalState = WalletSyncActivityAttributes.ContentState(
            status: status,
            progress: status == .completed ? 1.0 : 0.0,
            fullScanScriptCount: nil,
            currentWalletName: nil,
            completedWallets: completedWalletCount,
            totalWallets: totalWalletCount,
            errorMessage: errorMessage,
            isKyotoMode: isKyotoMode
        )

        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        Task {
            // Use .default so iOS keeps the activity visible on the Lock Screen
            // after it ends, giving the user time to see the final result.
            await activity.end(finalContent, dismissalPolicy: .default)
        }

        currentActivity = nil
        Log.print.info("[BGSync] Live Activity ended — status: \(status.rawValue)")
    }

    // MARK: - Sync Event Subscription

    private func subscribeSyncEvents(_ publisher: AnyPublisher<WalletSyncEvent, Never>) {
        cancellables.removeAll()

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSyncEvent(event)
            }
            .store(in: &cancellables)
    }

    private func unsubscribeSyncEvents() {
        cancellables.removeAll()
    }

    private func handleSyncEvent(_ event: WalletSyncEvent) {
        switch event {
        case .syncStateChanged(let walletId, let state):
            handleSyncStateChange(walletId: walletId, state: state)

        case .syncFailed(_, let error):
            endLiveActivity(status: .failed, errorMessage: error)
            endBackgroundExecution()

        case .balanceUpdated, .selectedWalletSynced,
             .cooldownActive, .alreadySyncing, .transactionsUpdated:
            break
        }
    }

    private func handleSyncStateChange(walletId: UUID, state: WalletSyncState) {
        var contentState = WalletSyncActivityAttributes.ContentState(
            status: .syncing,
            progress: 0.0,
            fullScanScriptCount: nil,
            currentWalletName: walletNames[walletId],
            completedWallets: completedWalletCount,
            totalWallets: totalWalletCount,
            errorMessage: nil,
            isKyotoMode: isKyotoMode
        )

        switch state {
        case .syncing(let progress):
            // Throttle progress updates to avoid hitting iOS rate limits.
            let now = Date()
            guard now.timeIntervalSince(lastProgressUpdate) >= 1.0 else { return }
            lastProgressUpdate = now

            contentState.status = .syncing
            contentState.progress = progress

        case .fullScanning(let count):
            let now = Date()
            guard now.timeIntervalSince(lastProgressUpdate) >= 1.0 else { return }
            lastProgressUpdate = now

            contentState.status = .fullScanning
            contentState.fullScanScriptCount = count

        case .synced:
            completedWalletCount += 1
            contentState.completedWallets = completedWalletCount

            if completedWalletCount >= totalWalletCount {
                endSync()
                return
            }

        case .failed(let error):
            endLiveActivity(status: .failed, errorMessage: error)
            endBackgroundExecution()
            return

        case .idle, .queued:
            return
        }

        updateLiveActivity(with: contentState)
    }

    // MARK: - App Lifecycle

    /// Observes app lifecycle to request/end background execution only when needed.
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self, self.isSyncing else { return }
                self.requestBackgroundExecution()
            }
            .store(in: &appLifecycleCancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.endBackgroundExecution()
            }
            .store(in: &appLifecycleCancellables)
    }

    // MARK: - Background Execution

    /// Requests extended background execution time (~30s) from the system.
    private func requestBackgroundExecution() {
        guard backgroundTaskIdentifier == .invalid else { return }
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "WalletSync"
        ) { [weak self] in
            Log.print.warning("[BGSync] Background execution expired")
            self?.markWaitingBackground()
            self?.endBackgroundExecution()
        }
        Log.print.info("[BGSync] Background execution requested")
    }

    /// Updates the Live Activity to indicate the app is suspended and waiting
    /// for the system to resume execution.
    private func markWaitingBackground() {
        guard currentActivity != nil else { return }
        let state = WalletSyncActivityAttributes.ContentState(
            status: .syncing,
            progress: 0.0,
            fullScanScriptCount: nil,
            currentWalletName: nil,
            completedWallets: completedWalletCount,
            totalWallets: totalWalletCount,
            errorMessage: nil,
            isWaitingBackground: true,
            isKyotoMode: isKyotoMode
        )
        updateLiveActivity(with: state)
    }

    private func endBackgroundExecution() {
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }

    // MARK: - BGProcessingTask

    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            Log.print.info("[BGSync] BGProcessingTask scheduled")
        } catch {
            Log.print.error("[BGSync] Failed to schedule BGProcessingTask: \(error.localizedDescription)")
        }
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = { [weak self] in
            Log.print.warning("[BGSync] BGProcessingTask expired")
            self?.endLiveActivity(status: .failed, errorMessage: "Sync interrupted — time limit reached")
            self?.unsubscribeSyncEvents()
            task.setTaskCompleted(success: false)
        }

        Log.print.info("[BGSync] BGProcessingTask started")
    }
}
