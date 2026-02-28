import SwiftUI

// MARK: - Factory

struct SettingsViewFactory {
    /// Ponto de entrada do módulo.
    /// Retorna uma view que gerencia internamente o ciclo de vida do coordinator e do viewModel.
    static func build() -> some View {
        SettingsEntry()
    }
}

// MARK: - Entry point (dono dos @StateObject)

/// View privada que detém o ciclo de vida do `coordinator` e do `viewModel`,
/// garantindo que ambos sobrevivam a re-renders do pai.
private struct SettingsEntry: View {
    @StateObject private var coordinator = SettingsCoordinator()
    @StateObject private var viewModel   = SettingsViewModel()

    var body: some View {
        SettingsView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct SettingsView<ViewModel: SettingsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: SettingsCoordinator

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Text("Settings")
                .navigationTitle("Settings")
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .notifications:
                        Text("Notifications")
                    case .about:
                        Text("About")
                    }
                }
        }
    }
}
