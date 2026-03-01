import SwiftUI

// MARK: - Route

/// Navigation destinations within the Home module.
enum HomeRoute: Hashable {
}

// MARK: - Coordinator

/// Manages the navigation stack and modal presentation for the Home module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
///
/// ```swift
/// @EnvironmentObject var coordinator: HomeCoordinator
/// ```
final class HomeCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()
    @Published var showCustomizeWidgets = false

    func presentCustomizeWidgets() {
        showCustomizeWidgets = true
    }
}
