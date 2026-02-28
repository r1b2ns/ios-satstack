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
    /// Waits up to 3 seconds for the push token before proceeding without it.
    /// Returns an empty string if Live Activities are disabled or if an error occurs.
    func start(txId: String) async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.print.warning("⚠️ Live Activities disabled by user.")
            return ""
        }

        do {
            let attributes = TransactionActivityAttributes(txId: txId)
            let state = TransactionActivityAttributes.ContentState(
                confirmations: 0,
                status: .pending,
                txId: txId
            )

            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )

            currentActivity = activity

            let tokenHex = await awaitPushToken(for: activity)

            Log.print.info("🏃 Live Activity started — activityToken: \(tokenHex.prefix(16))…")
            return tokenHex

        } catch {
            Log.print.error("⚠️ Error starting Live Activity: \(error.localizedDescription)")
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

    /// Waits up to 3 seconds for the push token, returning the hex string or empty on timeout.
    private func awaitPushToken(for activity: Activity<TransactionActivityAttributes>) async -> String {
        await withTaskGroup(of: String.self) { group in
            group.addTask {
                for await data in activity.pushTokenUpdates {
                    return data.map { String(format: "%02x", $0) }.joined()
                }
                return ""
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return ""
            }
            let result = await group.next() ?? ""
            group.cancelAll()
            return result
        }
    }
}
