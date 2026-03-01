import ActivityKit
import Foundation

/// Centralizes all Live Activity interactions for transaction monitoring.
///
/// Responsible for starting, updating, and ending Live Activities,
/// as well as awaiting the APNs push token for the activity.
final class LiveActivityManager {

    // MARK: - State

    private var currentActivity: Activity<TransactionActivityAttributes>?

    // MARK: - Start

    /// Starts a new Live Activity for the given transaction and returns the push token hex string.
    ///
    /// The Live Activity is only created when a valid APNs push token can be obtained.
    /// If the system denies the token request (e.g. on Simulator or missing entitlement),
    /// no Live Activity is started and an empty string is returned so the caller can
    /// proceed with transaction registration without Live Activity support.
    func start(txId: String) async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.print.warning("⚠️ Live Activities disabled by user.")
            return ""
        }

        do {
            let attributes = TransactionActivityAttributes(txId: txId)
            let initialState = TransactionActivityAttributes.ContentState(
                confirmations: 0,
                status: .pending,
                txId: txId
            )

            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: .token
            )

            // The system may have already populated pushToken synchronously right after
            // Activity.request, so we check it before subscribing to pushTokenUpdates.
            // Subscribing first would miss the token if it was emitted before the
            // for-await loop started, since AsyncStream has no replay buffer.
            let tokenHex = await awaitPushToken(for: activity)

            guard !tokenHex.isEmpty else {
                Log.print.warning("⚠️ Push token not received — Live Activity will not be started.")
                return ""
            }

            currentActivity = activity
            Log.print.info("🏃 Live Activity started — activityToken: \(tokenHex.prefix(16))…")
            return tokenHex

        } catch {
            Log.print.warning("⚠️ Live Activity not started: \(error.localizedDescription)")
            return ""
        }
    }

    // MARK: - Update

    /// Updates the current Live Activity with data from a server response.
    func update(with response: WatchTransactionResponse) async {
        guard let activity = currentActivity else { return }

        let updatedState = TransactionActivityAttributes.ContentState(
            confirmations: response.confirmations,
            status: response.status,
            txId: response.txId,
            valueBtc: response.valueBtc,
            feeSats: response.feeSats
        )

        await activity.update(.init(state: updatedState, staleDate: nil))
    }

    // MARK: - End

    /// Ends the current Live Activity immediately.
    func end() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    // MARK: - Private

    /// Returns the push token for the activity as a hex string.
    ///
    /// Fast path: `activity.pushToken` is checked synchronously first, since the system
    /// can populate it immediately after `Activity.request`. Only if it is nil do we
    /// subscribe to `pushTokenUpdates` with a 5-second timeout. This avoids the race
    /// condition where the token is emitted before the async subscription starts.
    private func awaitPushToken(for activity: Activity<TransactionActivityAttributes>) async -> String {
        // Fast path — token already available right after Activity.request.
        if let token = activity.pushToken {
            Log.print.info("⚡️ Push token available immediately.")
            return token.map { String(format: "%02x", $0) }.joined()
        }

        // Slow path — wait for the token via the async stream with a timeout.
        return await withTaskGroup(of: String.self) { group in
            defer { group.cancelAll() }

            group.addTask {
                for await tokenData in activity.pushTokenUpdates {
                    return tokenData.map { String(format: "%02x", $0) }.joined()
                }
                return ""
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                Log.print.warning("⏱️ Push token not received within timeout — proceeding without it.")
                return ""
            }

            return await group.next() ?? ""
        }
    }
}
