import SwiftUI

// MARK: - Route

/// Navigation destinations within the TransactionList module.
enum TransactionListRoute: Hashable {
    case detail(txId: String)
}

// MARK: - Coordinator

/// Manages the navigation stack for the TransactionList module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
///
/// ```swift
/// @EnvironmentObject var coordinator: TransactionListCoordinator
///
/// Button("View details") {
///     coordinator.navigateToDetail(txId: tx.id)
/// }
/// ```
final class TransactionListCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()
    @Published var showRegisterTransaction = false

    // MARK: - Navigation

    func navigateToDetail(txId: String) {
        path.append(TransactionListRoute.detail(txId: txId))
    }

    func presentRegisterTransaction() {
        showRegisterTransaction = true
    }
}
