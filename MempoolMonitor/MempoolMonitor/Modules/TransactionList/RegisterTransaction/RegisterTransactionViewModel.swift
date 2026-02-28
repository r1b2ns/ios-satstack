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
    private let liveActivityManager: LiveActivityManager

    init(
        uiState: RegisterTransactionUiState = .init(),
        tokenManager: APNsTokenManager,
        api: MempoolMonitorAPIProtocol,
        liveActivityManager: LiveActivityManager
    ) {
        self.uiState = uiState
        self.tokenManager = tokenManager
        self.api = api
        self.liveActivityManager = liveActivityManager
    }

    /// Convenience initializer that uses shared instances.
    convenience init() {
        self.init(
            tokenManager: .shared,
            api: MempoolMonitorAPI.shared,
            liveActivityManager: LiveActivityManager()
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
        let activityToken = await liveActivityManager.start(txId: cleanTxid)

        // 2. Register the transaction on the server.
        do {
            let response = try await api.watchTransaction(
                txId: cleanTxid,
                deviceToken: tokenManager.deviceToken ?? "",
                activityToken: activityToken.isEmpty ? nil : activityToken
            )
            uiState.transaction = response

            // 3. Update the Live Activity with the real data from the server.
            await liveActivityManager.update(with: response)

            uiState.statusMessage = "Watching transaction."
            uiState.statusIsSuccess = true

            try? await Task.sleep(for: .seconds(1))
            uiState.shouldDismiss = true
        } catch {
            uiState.statusMessage = (error as? HTTPError)?.localizedDescription
                ?? error.localizedDescription
            uiState.statusIsSuccess = false
            await liveActivityManager.end()
        }
    }
}
