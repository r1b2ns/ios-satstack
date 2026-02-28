import Foundation
import SwiftUI

// MARK: - Protocol

protocol TransactionListViewModelProtocol: ObservableObject {
    var uiState: TransactionListUiState { get set }
    func loadTransactions() async
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

    init(
        uiState: TransactionListUiState = .init(),
        storage: PersistentStorable
    ) {
        self.uiState = uiState
        self.storage = storage
    }

    /// Convenience initializer that uses the shared SwiftData store.
    @MainActor
    convenience init() {
        self.init(storage: SwiftDataStorable.shared)
    }

    // MARK: - Actions

    func loadTransactions() async {
        Task { @MainActor in
            uiState.isLoading = true
            defer { uiState.isLoading = false }
            
            do {
                uiState.transactions = try await storage.fetchAll(WatchTransactionResponse.self)
                
            } catch {
                Log.print.error("❌ Failed to load transactions: \(error.localizedDescription)")
            }
        }
    }
}
