import SwiftUI

// MARK: - Route

/// Navigation destinations within the Settings module.
enum SettingsRoute: Hashable {
    case notifications
    case about
    case theme
    case network
    case openSourceSoftware
    case buyMeACoffee
    case fiatCurrency
}

// MARK: - Coordinator

/// Manages the navigation stack for the Settings module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
///
/// ```swift
/// @EnvironmentObject var coordinator: SettingsCoordinator
///
/// Button("Theme") {
///     coordinator.navigateToTheme()
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

    func navigateToTheme() {
        path.append(SettingsRoute.theme)
    }

    func navigateToNetwork() {
        path.append(SettingsRoute.network)
    }

    func navigateToOpenSourceSoftware() {
        path.append(SettingsRoute.openSourceSoftware)
    }

    func navigateToBuyMeACoffee() {
        path.append(SettingsRoute.buyMeACoffee)
    }

    func navigateToFiatCurrency() {
        path.append(SettingsRoute.fiatCurrency)
    }
}
