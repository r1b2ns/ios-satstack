import SwiftUI

// MARK: - Factory

struct TransactionListViewFactory {
    /// Ponto de entrada do módulo.
    /// Retorna uma view que gerencia internamente o ciclo de vida do coordinator e do viewModel.
    static func build() -> some View {
        TransactionListEntry()
    }
}

// MARK: - Entry point (dono dos @StateObject)

/// View privada que detém o ciclo de vida do `coordinator` e do `viewModel`,
/// garantindo que ambos sobrevivam a re-renders do pai.
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
