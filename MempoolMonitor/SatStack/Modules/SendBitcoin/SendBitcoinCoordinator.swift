import SwiftUI

// MARK: - Route

/// Navigation destinations within the SendBitcoin module.
enum SendBitcoinRoute: Hashable {
    case reviewTransaction
    case transactionSuccess
}

// MARK: - Coordinator

/// Manages the navigation stack for the SendBitcoin module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
final class SendBitcoinCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()

    // MARK: - Navigation

    func navigateToReview() {
        path.append(SendBitcoinRoute.reviewTransaction)
    }

    func navigateToSuccess() {
        path.append(SendBitcoinRoute.transactionSuccess)
    }
}
