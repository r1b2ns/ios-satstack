import ActivityKit
import Foundation
import SwiftUI

// MARK: - Protocol

@MainActor
protocol RegisterTransactionViewModelProtocol: ObservableObject {
    var uiState: RegisterTransactionUiState { get set }

    func checkClipboard()
    func pasteFromClipboard()
    func watchTransaction() async
}

// MARK: - UiState

struct RegisterTransactionUiState {
    var txid: String = ""
    var statusMessage: String = ""
    var statusIsSuccess: Bool = false
    var isLoading: Bool = false
    var shouldDismiss: Bool = false
    var clipboardHasContent: Bool = false
    var transaction: WatchTransactionResponse?
}

// MARK: - ViewModel

final class RegisterTransactionViewModel: @MainActor RegisterTransactionViewModelProtocol {
    @Published var uiState: RegisterTransactionUiState

    private let tokenManager: APNsTokenManager
    private let api: MempoolMonitorAPIProtocol
    private var currentActivity: Activity<TransactionActivityAttributes>?

    init(
        uiState: RegisterTransactionUiState = .init(),
        tokenManager: APNsTokenManager,
        api: MempoolMonitorAPIProtocol
    ) {
        self.uiState = uiState
        self.tokenManager = tokenManager
        self.api = api
    }
    
    /// Convenience initializer that uses shared instances.
    convenience init() {
        self.init(
            tokenManager: .shared,
            api: MempoolMonitorAPI.shared
        )
    }

    // MARK: - Actions

    func checkClipboard() {
        uiState.clipboardHasContent = UIPasteboard.general.hasStrings
    }

    func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string else { return }
        uiState.txid = text
    }

    func watchTransaction() async {
        let cleanTxid = uiState.txid.trimmingCharacters(in: .whitespaces)
        guard !cleanTxid.isEmpty else { return }

        uiState.isLoading = true
        uiState.statusMessage = ""
        defer { uiState.isLoading = false }

        // 1. Start the Live Activity to obtain the push token.
        let activityToken = await beginLiveActivity(txId: cleanTxid)

        // 2. Register the transaction on the server.
        do {
            let response = try await api.watchTransaction(
                txId: cleanTxid,
                deviceToken: tokenManager.deviceToken ?? "",
                activityToken: activityToken.isEmpty ? nil : activityToken
            )
            uiState.transaction = response

            // 3. Update the Live Activity with the real data from the server.
            await updateLiveActivity(with: response)

            uiState.statusMessage = "Watching transaction."
            uiState.statusIsSuccess = true

            try? await Task.sleep(for: .seconds(1))
            uiState.shouldDismiss = true
        } catch {
            uiState.statusMessage = (error as? HTTPError)?.localizedDescription
                ?? error.localizedDescription
            uiState.statusIsSuccess = false
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Live Activity

    /// Updates the running Live Activity with the server response data.
    private func updateLiveActivity(with response: WatchTransactionResponse) async {
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

    private func beginLiveActivity(txId: String) async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities disabled by user.")
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

            let tokenHex = await withTaskGroup(of: String.self) { group in
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

            print("🏃 Live Activity started — activityToken: \(tokenHex.prefix(16))…")
            return tokenHex

        } catch {
            print("⚠️ Error starting Live Activity: \(error.localizedDescription)")
            return ""
        }
    }
}
