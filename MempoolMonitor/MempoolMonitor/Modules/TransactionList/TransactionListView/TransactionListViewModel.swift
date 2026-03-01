import Combine
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
    /// TxIds currently being refreshed via the API.
    var loadingTxIds: Set<String> = []

    var pendingTransactions: [WatchTransactionResponse] {
        transactions.filter { $0.status != .confirmed }
    }

    var confirmedTransactions: [WatchTransactionResponse] {
        transactions.filter { $0.status == .confirmed }
    }

    func isRefreshing(_ txId: String) -> Bool {
        loadingTxIds.contains(txId)
    }
}

// MARK: - ViewModel

final class TransactionListViewModel: TransactionListViewModelProtocol {
    @Published var uiState: TransactionListUiState

    private let storage: PersistentStorable
    private let api: MempoolMonitorAPIProtocol
    private var cancellables = Set<AnyCancellable>()

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
                uiState.loadingTxIds = Set(stored.map(\.txId))

                // 2. Cancel any in-flight refresh before starting a new one.
                cancellables.removeAll()

                // 3. Refresh all transactions in parallel via Combine.
                //    Publishers.MergeMany subscribes to every publisher simultaneously,
                //    so all API calls run concurrently. Results arrive as each call completes.
                Publishers.MergeMany(stored.map { makeRefreshPublisher(for: $0.txId) })
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] result in
                        guard let self else { return }
                        self.uiState.loadingTxIds.remove(result.txId)
                        guard let refreshed = result.response else { return }
                        if let index = self.uiState.transactions.firstIndex(where: { $0.txId == refreshed.txId }) {
                            self.uiState.transactions[index] = refreshed
                        }
                        Task {
                            do {
                                try await self.storage.save(refreshed, id: refreshed.txId)
                            } catch {
                                Log.print.error("❌ Failed to persist transaction: \(error.localizedDescription)")
                            }
                        }
                    }
                    .store(in: &cancellables)

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
                uiState.loadingTxIds.remove(txId)
                Log.print.info("🗑️ Transaction deleted: \(txId)")
            } catch {
                Log.print.error("❌ Failed to delete transaction \(txId): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    /// A named result type for each parallel refresh call.
    private struct RefreshResult {
        let txId: String
        let response: WatchTransactionResponse?
    }

    /// Creates a Combine publisher that fetches a single transaction from the API.
    ///
    /// - Uses `Deferred` so the network call starts only upon subscription.
    /// - Never fails: network errors resolve to a `nil` response so the
    ///   loading indicator is removed regardless of outcome.
    private func makeRefreshPublisher(for txId: String) -> AnyPublisher<RefreshResult, Never> {
        Deferred {
            Future { [weak self] promise in
                Task { [weak self] in
                    let response = try? await self?.api.fetchTransaction(txId: txId)
                    promise(.success(RefreshResult(txId: txId, response: response)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
