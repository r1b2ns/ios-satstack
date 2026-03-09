import SwiftUI

// MARK: - Route

enum WalletsRoute: Hashable {
    case detail(walletId: UUID)
}

// MARK: - Coordinator

final class WalletsCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()

    func navigateToDetail(walletId: UUID) {
        path.append(WalletsRoute.detail(walletId: walletId))
    }
}
