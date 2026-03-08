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
    var isShowingError: Bool = false
    var errorMessage: String?
    var transaction: WatchTransactionResponse?
}

// MARK: - ViewModel

final class RegisterTransactionViewModel: @MainActor RegisterTransactionViewModelProtocol {
    @Published var uiState: RegisterTransactionUiState

    private let tokenManager: APNsTokenManager
    private let api: MempoolMonitorAPIProtocol
    private let liveActivityManager: LiveActivityManager
    private let storage: PersistentStorable

    init(
        uiState: RegisterTransactionUiState = .init(),
        tokenManager: APNsTokenManager,
        api: MempoolMonitorAPIProtocol,
        liveActivityManager: LiveActivityManager,
        storage: PersistentStorable
    ) {
        self.uiState = uiState
        self.tokenManager = tokenManager
        self.api = api
        self.liveActivityManager = liveActivityManager
        self.storage = storage
    }

    /// Convenience initializer that uses shared instances.
    convenience init() {
        self.init(
            tokenManager: .shared,
            api: MempoolMonitorAPI.shared,
            liveActivityManager: LiveActivityManager(),
            storage: SwiftDataStorable.shared
        )
    }

    // MARK: - Validation

    /// A valid Bitcoin transaction ID is a 64-character hexadecimal string.
    private static let txidRegex = /^[a-fA-F0-9]{64}$/

    private func isValidTxid(_ txid: String) -> Bool {
        txid.wholeMatch(of: Self.txidRegex) != nil
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
        let cleanTxid = uiState.txid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTxid.isEmpty else { return }

        guard isValidTxid(cleanTxid) else {
            uiState.errorMessage = "Invalid transaction ID. A valid TXID must be a 64-character hexadecimal string."
            uiState.isShowingError = true
            return
        }

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

            // 4. Persist the transaction locally (skip if already saved).
            let alreadySaved = (try? await storage.fetch(WatchTransactionResponse.self, id: cleanTxid)) != nil
            if !alreadySaved {
                try? await storage.save(response, id: cleanTxid)
                Log.print.info("💾 Transaction saved to SwiftData: \(cleanTxid)")
            } else {
                Log.print.info("ℹ️ Transaction already in SwiftData, skipping save: \(cleanTxid)")
            }

            uiState.statusMessage = "Watching transaction."
            uiState.statusIsSuccess = true

            try? await Task.sleep(for: .seconds(1))
            uiState.shouldDismiss = true
        } catch {
            Log.print.error("[RegisterTransaction] Watch failed: \(error.localizedDescription)")
            uiState.errorMessage = (error as? HTTPError)?.localizedDescription
                ?? error.localizedDescription
            uiState.isShowingError = true
            await liveActivityManager.end()
        }
    }
}
