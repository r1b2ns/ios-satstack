import SwiftUI

// MARK: - Factory

struct TransactionListViewFactory {
    /// Module entry point.
    /// Returns a view that internally manages the lifecycle of the coordinator and viewModel.
    static func build() -> some View {
        TransactionListEntry()
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
private struct TransactionListEntry: View {
    @StateObject private var coordinator = TransactionListCoordinator()
    @StateObject private var viewModel   = TransactionListViewModel()

    var body: some View {
        TransactionListView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct TransactionListView<ViewModel: TransactionListViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: TransactionListCoordinator

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Text("Transaction List")
                .navigationTitle("Transactions")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            coordinator.presentRegisterTransaction()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $coordinator.showRegisterTransaction) {
                    RegisterTransactionView()
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.automatic)
                }
                .navigationDestinations()
        }
    }
}

// MARK: - Navigation destinations

private extension View {
    @ViewBuilder
    func navigationDestinations() -> some View {
        self.navigationDestination(for: TransactionListRoute.self) { route in
            switch route {
            case .detail(let txId):
                Text("Detail: \(txId)")
            }
        }
    }
}
