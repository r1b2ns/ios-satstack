import SwiftUI

// MARK: - Route

/// Navigation destinations within the Settings module.
enum SettingsRoute: Hashable {
    case notifications
    case about
    case network
    case openSourceSoftware
    case buyMeACoffee
    case fiatCurrency
    case balanceFormat
    case syncPreference
}

// MARK: - Coordinator

/// Manages the navigation stack for the Settings module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
final class SettingsCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()

    // MARK: - Navigation

    func navigateToNotifications() {
        path.append(SettingsRoute.notifications)
    }

    func navigateToAbout() {
        path.append(SettingsRoute.about)
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

    func navigateToBalanceFormat() {
        path.append(SettingsRoute.balanceFormat)
    }

    func navigateToSyncPreference() {
        path.append(SettingsRoute.syncPreference)
    }
}
