import SwiftUI

// MARK: - Route

/// Destinos de navegação dentro do módulo Settings.
enum SettingsRoute: Hashable {
    case notifications
    case about
}

// MARK: - Coordinator

/// Gerencia a pilha de navegação do módulo Settings.
///
/// Exposto via `environmentObject` para que qualquer view do módulo
/// possa disparar transições sem acoplamento direto.
///
/// ```swift
/// @EnvironmentObject var coordinator: SettingsCoordinator
///
/// Button("Notificações") {
///     coordinator.navigateToNotifications()
/// }
/// ```
final class SettingsCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()

    // MARK: - Navigation

    func navigateToNotifications() {
        path.append(SettingsRoute.notifications)
    }

    func navigateToAbout() {
        path.append(SettingsRoute.about)
    }
}
