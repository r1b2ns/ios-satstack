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
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.appTheme) private var theme

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                buildThemeRow()
                buildAPNsTokenIndicator()
            }
            .navigationTitle("Settings")
            .navigationDestinations()
        }
    }

    // MARK: - Theme row

    private func buildThemeRow() -> some View {
        Button {
            coordinator.navigateToTheme()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.title3)
                    .foregroundStyle(theme.colors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme")
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                    Text(themeManager.current.displayName)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.contentSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.colors.contentTertiary)
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(.foreground)
    }

    // MARK: - APNs indicator

    private func buildAPNsTokenIndicator() -> some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.uiState.hasAPNsToken
                  ? "bell.badge.fill"
                  : "bell.slash.fill")
                .foregroundStyle(viewModel.uiState.hasAPNsToken ? theme.colors.success : theme.colors.contentSecondary)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Push Notifications")
                    .font(theme.typography.subheadline)
                    .fontWeight(.medium)
                Text(viewModel.uiState.hasAPNsToken ? "Registered" : "Not registered")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.contentSecondary)
            }

            Spacer()

            Image(systemName: viewModel.uiState.hasAPNsToken
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .foregroundStyle(viewModel.uiState.hasAPNsToken ? theme.colors.success : theme.colors.destructive)
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
            case .theme:
                ThemeSettingsView()
            }
        }
    }
}
