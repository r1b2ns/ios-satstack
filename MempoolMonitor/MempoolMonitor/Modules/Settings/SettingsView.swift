import SwiftUI

// MARK: - Factory

struct SettingsViewFactory {
    /// Module entry point.
    /// Returns a view that internally manages the lifecycle of the coordinator and viewModel.
    static func build() -> some View {
        SettingsEntry()
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
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
            List {
                buildAPNsTokenIndicator()
            }
            .navigationTitle("Settings")
            .navigationDestinations()
        }
    }

    // MARK: - Subviews

    private func buildAPNsTokenIndicator() -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.uiState.hasAPNsToken
                  ? "bell.badge.fill"
                  : "bell.slash.fill")
                .foregroundStyle(viewModel.uiState.hasAPNsToken ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Push Notifications")
                    .font(.subheadline.weight(.medium))
                Text(viewModel.uiState.hasAPNsToken ? "Registered" : "Not registered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: viewModel.uiState.hasAPNsToken
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .foregroundStyle(viewModel.uiState.hasAPNsToken ? .green : .red)
        }
    }
}

// MARK: - Navigation destinations

private extension View {
    @ViewBuilder
    func navigationDestinations() -> some View {
        self.navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .notifications:
                Text("Notifications")
            case .about:
                Text("About")
            }
        }
    }
}
