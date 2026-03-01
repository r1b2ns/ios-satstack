import Foundation
import SwiftUI

// MARK: - Protocol

protocol TransactionListViewModelProtocol: ObservableObject {
    var uiState: TransactionListUiState { get set }
    func loadTransactions() async
    func deleteTransaction(txId: String) async
}

// MARK: - UiState

struct TransactionListUiState {
    var transactions: [WatchTransactionResponse] = []
    var isLoading: Bool = false

    var pendingTransactions: [WatchTransactionResponse] {
        transactions.filter { $0.status != .confirmed }
    }

    var confirmedTransactions: [WatchTransactionResponse] {
        transactions.filter { $0.status == .confirmed }
    }
}

// MARK: - ViewModel

final class TransactionListViewModel: TransactionListViewModelProtocol {
    @Published var uiState: TransactionListUiState

    private let storage: PersistentStorable
    private let api: MempoolMonitorAPIProtocol

    init(
        uiState: TransactionListUiState = .init(),
        storage: PersistentStorable,
        api: MempoolMonitorAPIProtocol
    ) {
        self.uiState = uiState
        self.storage = storage
        self.api = api
    }

    /// Convenience initializer that uses the shared SwiftData store and API.
    @MainActor
    convenience init() {
        self.init(storage: SwiftDataStorable.shared, api: MempoolMonitorAPI.shared)
    }

    // MARK: - Actions

    func loadTransactions() async {
        Task { @MainActor in
            uiState.isLoading = true
            defer { uiState.isLoading = false }

            do {
                // 1. Display saved transactions immediately from local storage.
                let stored = try await storage.fetchAll(WatchTransactionResponse.self)
                uiState.transactions = stored

                // 2. Refresh each transaction from the API and persist the updated state.
                for transaction in stored {
                    guard let refreshed = try? await api.fetchTransaction(txId: transaction.txId) else { continue }
                    do {
                        try await storage.save(refreshed, id: refreshed.txId)
                    } catch {
                        Log.print.error("❌ Failed to persist transaction: \(error.localizedDescription)")
                    }
                    if let index = uiState.transactions.firstIndex(where: { $0.txId == refreshed.txId }) {
                        uiState.transactions[index] = refreshed
                    }
                }
            } catch {
                Log.print.error("❌ Failed to load transactions: \(error.localizedDescription)")
            }
        }
    }

    func deleteTransaction(txId: String) async {
        Task { @MainActor in
            do {
                try await storage.delete(WatchTransactionResponse.self, id: txId)
                uiState.transactions.removeAll { $0.txId == txId }
                Log.print.info("🗑️ Transaction deleted: \(txId)")
            } catch {
                Log.print.error("❌ Failed to delete transaction \(txId): \(error.localizedDescription)")
            }
        }
    }
}
