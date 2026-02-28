import SwiftUI

// MARK: - Route

/// Destinos de navegação dentro do módulo TransactionList.
enum TransactionListRoute: Hashable {
    case detail(txId: String)
}

// MARK: - Coordinator

/// Gerencia a pilha de navegação do módulo TransactionList.
///
/// Exposto via `environmentObject` para que qualquer view do módulo
/// possa disparar transições sem acoplamento direto.
///
/// ```swift
/// @EnvironmentObject var coordinator: TransactionListCoordinator
///
/// Button("Ver detalhes") {
///     coordinator.navigateToDetail(txId: tx.id)
/// }
/// ```
final class TransactionListCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()

    // MARK: - Navigation

    func navigateToDetail(txId: String) {
        path.append(TransactionListRoute.detail(txId: txId))
    }
}
