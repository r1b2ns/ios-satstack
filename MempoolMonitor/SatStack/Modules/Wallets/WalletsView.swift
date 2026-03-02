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

    /// Height of a full wallet card.
    private let cardHeight: CGFloat = 200
    /// Height of the visible header strip when cards are stacked.
    private let headerHeight: CGFloat = 68

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            buildContent()
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .toolbar { buildToolbar() }
                .sheet(isPresented: Binding(
                    get: { viewModel.uiState.isPresentingAddSheet },
                    set: { viewModel.uiState.isPresentingAddSheet = $0 }
                )) {
                    buildAddSheet()
                }
                .navigationDestinations()
                .alert("Rename Wallet", isPresented: Binding(
                    get: { viewModel.uiState.isPresentingRenameAlert },
                    set: { viewModel.uiState.isPresentingRenameAlert = $0 }
                )) {
                    TextField("Wallet name", text: Binding(
                        get: { viewModel.uiState.renameText },
                        set: { viewModel.uiState.renameText = $0 }
                    ))
                    Button("Save") {
                        if let id = viewModel.uiState.selectedWalletId {
                            viewModel.updateWalletName(id: id, name: viewModel.uiState.renameText)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }
        }
    }

    // MARK: - Navigation title

    private var navigationTitle: String {
        guard let id = viewModel.uiState.selectedWalletId,
              let wallet = viewModel.uiState.wallets.first(where: { $0.id == id })
        else { return "Wallets" }
        return wallet.name
    }

    // MARK: - Content

    @ViewBuilder
    private func buildContent() -> some View {
        if viewModel.uiState.isLoadingWallets {
            buildLoadingState(label: "Loading wallets…")
        } else if viewModel.uiState.wallets.isEmpty {
            buildEmptyState()
        } else if let wallet = selectedWallet {
            buildDetailView(wallet: wallet)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal:   .move(edge: .bottom).combined(with: .opacity)
                ))
        } else {
            buildStackedView()
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal:   .opacity
                ))
        }
    }

    private var selectedWallet: Wallet? {
        guard let id = viewModel.uiState.selectedWalletId else { return nil }
        return viewModel.uiState.wallets.first(where: { $0.id == id })
    }

    // MARK: - Stacked view

    /// Apple Wallet-style collapsed stack.
    ///
    /// The first card sits on top (highest `zIndex`) and is fully visible.
    /// Each subsequent card is offset down by `headerHeight`, peeking from
    /// behind the card above — exactly like the iOS Wallet app.
    private func buildStackedView() -> some View {
        let wallets = viewModel.uiState.wallets
        let totalHeight = CGFloat(wallets.count - 1) * headerHeight + cardHeight

        return ScrollView {
            ZStack(alignment: .top) {
                ForEach(Array(wallets.enumerated()), id: \.element.id) { index, wallet in
                    WalletCardView(wallet: wallet)
                        .offset(y: CGFloat(index) * headerHeight)
                        .zIndex(Double(index))
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.42)) {
                                viewModel.selectWallet(wallet.id)
                            }
                        }
                }
            }
            .frame(height: totalHeight)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Detail view (selected card + transactions)

    private func buildDetailView(wallet: Wallet) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                buildSelectedCard(wallet: wallet)
                buildTransactionList()
            }
            .padding(.top, 8)
        }
    }

    /// The expanded card at the top of the detail view.
    /// Dragging down on the card returns to the stacked view.
    private func buildSelectedCard(wallet: Wallet) -> some View {
        WalletCardView(wallet: wallet)
            .padding(.horizontal, 20)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let isDownward  = value.translation.height > 60
                        let isVertical  = abs(value.translation.height) > abs(value.translation.width)
                        if isDownward && isVertical {
                            withAnimation(.spring(duration: 0.42)) {
                                viewModel.deselectWallet()
                            }
                        }
                    }
            )
    }

    // MARK: - Transaction list

    private func buildTransactionList() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            buildTransactionHeader()
            buildTransactionRows()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
    }

    private func buildTransactionHeader() -> some View {
        Text("Latest Transactions")
            .font(.title3)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func buildTransactionRows() -> some View {
        if viewModel.uiState.isLoadingTransactions {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            let txs = viewModel.uiState.transactions
            ForEach(Array(txs.enumerated()), id: \.element.id) { index, tx in
                buildTransactionRow(tx)
                if index < txs.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func buildTransactionRow(_ tx: WalletTransaction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.shortAddress)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(tx.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("₿ \(String(format: "%.5f", tx.valueBTC))")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading state

    private func buildLoadingState(label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty state

    private func buildEmptyState() -> some View {
        ContentUnavailableView(
            "No Wallets",
            systemImage: "creditcard",
            description: Text("Tap + to add your first wallet.")
        )
    }

    // MARK: - Add sheet

    private func buildAddSheet() -> some View {
        AddWalletSheetView(viewModel: viewModel)
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

        if viewModel.uiState.selectedWalletId != nil {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(duration: 0.42)) {
                        viewModel.deselectWallet()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showRenameAlert()
                } label: {
                    Image(systemName: "pencil")
                }
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
