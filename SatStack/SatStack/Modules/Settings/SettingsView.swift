import StoreKit
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
    @Environment(\.requestReview) private var requestReview

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                Section("Notifications") {
                    buildAPNsTokenIndicator()
                }
                Section("Network") {
                    buildNetworkRow()
                }
                Section("Preferences") {
                    buildFiatCurrencyRow()
                }
                Section("About") {
                    buildProjectOnGitHubRow()
                    buildOpenSourceRow()
                }
                Section {
                    buildBuyMeACoffeeRow()
                    buildRateAppRow()
                } header: {
                    Text("Support")
                } footer: {
                    Text(appVersion)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
            }
            .navigationTitle("Settings")
            .navigationDestinations()
        }
    }

    // MARK: - APNs indicator

    private func buildAPNsTokenIndicator() -> some View {
        Button {
            guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.uiState.hasAPNsToken
                      ? "bell.badge.fill"
                      : "bell.slash.fill")
                    .foregroundStyle(viewModel.uiState.hasAPNsToken ? Color.green : Color.secondary)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(viewModel.uiState.hasAPNsToken ? "Registered" : "Not registered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.foreground)
    }

    // MARK: - Network

    private func buildNetworkRow() -> some View {
        Button {
            coordinator.navigateToNetwork()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "network")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Network")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(BDKNetworkConfig.networkName.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.foreground)
    }

    // MARK: - Fiat Currency

    private func buildFiatCurrencyRow() -> some View {
        Button {
            coordinator.navigateToFiatCurrency()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fiat Price Preferred")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(viewModel.uiState.preferredCurrency.flag) \(viewModel.uiState.preferredCurrency.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.foreground)
    }

    // MARK: - Project on GitHub

    private func buildProjectOnGitHubRow() -> some View {
        Link(destination: URL(string: "https://github.com/r1b2ns/ios-satstack")!) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Project on GitHub")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("View the source code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Open Source Software

    private func buildOpenSourceRow() -> some View {
        Button {
            coordinator.navigateToOpenSourceSoftware()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Source Software")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Acknowledgements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.foreground)
    }

    // MARK: - Buy Me a Coffee

    private func buildBuyMeACoffeeRow() -> some View {
        Button {
            coordinator.navigateToBuyMeACoffee()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Buy Me a Coffee")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Support the developer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.foreground)
    }

    // MARK: - Rate App

    private func buildRateAppRow() -> some View {
        Button {
            requestReview()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate the App")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Leave a review on the App Store")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .foregroundStyle(.foreground)
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
            case .network:
                NetworkStatusView()
            case .openSourceSoftware:
                OpenSourceView()
            case .buyMeACoffee:
                BuyMeACoffeeView()
            case .fiatCurrency:
                FiatCurrencyView()
            }
        }
    }
}
