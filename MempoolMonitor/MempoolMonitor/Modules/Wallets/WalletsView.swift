import SwiftUI

// MARK: - Factory

struct WalletsViewFactory {
    /// Module entry point — manages coordinator and viewModel lifecycle internally.
    static func build() -> some View {
        WalletsEntry()
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
private struct WalletsEntry: View {
    @StateObject private var coordinator = WalletsCoordinator()
    @StateObject private var viewModel   = WalletsViewModel()

    var body: some View {
        WalletsView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct WalletsView<ViewModel: WalletsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: WalletsCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            buildContent()
                .navigationTitle("Wallets")
                .toolbar { buildToolbar() }
                .sheet(isPresented: Binding(
                    get: { viewModel.uiState.isPresentingAddSheet },
                    set: { viewModel.uiState.isPresentingAddSheet = $0 }
                )) {
                    buildAddSheet()
                }
                .navigationDestinations()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func buildContent() -> some View {
        if viewModel.uiState.wallets.isEmpty {
            buildEmptyState()
        } else {
            buildCardStack()
        }
    }

    /// Renders wallets as vertically stacked, overlapping cards — inspired by Apple Wallet.
    ///
    /// Cards are layered so the first wallet sits on top; each subsequent card
    /// is partially hidden beneath the one above it, revealing only its top edge.
    private func buildCardStack() -> some View {
        ScrollView {
            LazyVStack(spacing: -140) {
                ForEach(
                    Array(viewModel.uiState.wallets.enumerated()),
                    id: \.element.id
                ) { index, wallet in
                    WalletCardView(wallet: wallet)
                        .zIndex(Double(viewModel.uiState.wallets.count - index))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 220)
        }
    }

    private func buildEmptyState() -> some View {
        ContentUnavailableView(
            "No Wallets",
            systemImage: "creditcard",
            description: Text("Tap + to add your first wallet.")
        )
    }

    // MARK: - Add sheet

    private func buildAddSheet() -> some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "hammer.circle",
            description: Text("Wallet creation will be available in a future update.")
        )
        .presentationDetents([.medium])
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.showAddWallet()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Navigation destinations

private extension View {
    @ViewBuilder
    func navigationDestinations() -> some View {
        self.navigationDestination(for: WalletsRoute.self) { _ in
            EmptyView()
        }
    }
}
