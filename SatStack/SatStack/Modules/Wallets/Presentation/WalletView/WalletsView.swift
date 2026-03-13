import SwiftUI
import TipKit
import UserNotifications

// MARK: - FullScanTip

/// Tip displayed in the wallet detail view suggesting a full scan when balances seem incorrect.
struct FullScanTip: Tip {
    var title: Text {
        Text("Balance doesn't look right?")
    }

    var message: Text? {
        Text("Try running a Full Scan to rescan all addresses from scratch.")
    }

    var image: Image? {
        Image(systemName: "arrow.triangle.2.circlepath")
    }

    var actions: [Action] {
        Action(id: "full-scan", title: "Full Scan")
    }
}

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

    @State private var showNotificationPermission = false

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            buildContent()
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .toolbar { buildToolbar() }
                .sheet(isPresented: $showNotificationPermission) {
                    buildNotificationPermissionSheet()
                }
                .sheet(isPresented: $viewModel.uiState.isPresentingAddSheet) {
                    buildAddSheet()
                }
                .sheet(isPresented: $viewModel.uiState.isPresentingWalletSettings) {
                    buildSettingsSheet()
                }
                .sheet(isPresented: $viewModel.uiState.isPresentingReceiveSheet) {
                    ReceiveAddressSheet(address: viewModel.uiState.receiveAddress)
                }
                .sheet(isPresented: $viewModel.uiState.isPresentingSendSheet) {
                    if let wallet = selectedWallet {
                        SendBitcoinViewFactory.build(wallet: wallet) {
                            Task { await viewModel.syncAllWallets() }
                        }
                    }
                }
                .navigationDestinations()
                .alert("Rename Wallet", isPresented: $viewModel.uiState.isPresentingRenameAlert) {
                    TextField("Wallet name", text: $viewModel.uiState.renameText)
                    Button("Save") {
                        if let id = viewModel.uiState.selectedWalletId {
                            viewModel.updateWalletName(id: id, name: viewModel.uiState.renameText)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .alert("Sync Failed", isPresented: $viewModel.uiState.isPresentingSyncError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.uiState.syncErrorMessage ?? "An unknown error occurred.")
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
    private func buildStackedView() -> some View {
        let wallets = viewModel.uiState.wallets
        let totalHeight = CGFloat(wallets.count - 1) * headerHeight + cardHeight

        return ScrollView {
            VStack(spacing: 0) {
                buildTotalBalanceHeader()

                ZStack(alignment: .top) {
                    ForEach(Array(wallets.enumerated()), id: \.element.id) { index, wallet in
                        WalletCardView(
                                wallet: wallet,
                                balanceSats: viewModel.uiState.walletBalances[wallet.id],
                                syncState: viewModel.uiState.walletSyncStates[wallet.id] ?? .idle
                            )
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
                .padding(.bottom, 32)
            }
            .padding(.top, 4)
        }
        .refreshable {
            await viewModel.fullScanAllWallets()
        }
    }

    private func buildTotalBalanceHeader() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Total Balance")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let total = viewModel.uiState.totalWalletBalanceSats {
                BalanceDisplayFormatView(sats: total)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            } else {
                Text("₿ -.--------")
                    .font(.title2)
                    .fontWeight(.bold)
                    .redacted(reason: .placeholder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Detail view (selected card + transactions)

    private let fullScanTip = FullScanTip()

    private func buildDetailView(wallet: Wallet) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                buildFullScanTip()
                buildSelectedCard(wallet: wallet)
                buildTransactionList()
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            buildActionBar(isWatchOnly: wallet.mnemonicPhrase == nil)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    /// The expanded card at the top of the detail view.
    /// Shows the live balance from the ViewModel while syncing.
    /// Dragging down on the card returns to the stacked view.
    private func buildSelectedCard(wallet: Wallet) -> some View {
        WalletCardView(
            wallet: wallet,
            balanceSats: viewModel.uiState.selectedWalletBalanceSats
                ?? viewModel.uiState.walletBalances[wallet.id],
            syncState: viewModel.uiState.walletSyncStates[wallet.id] ?? .idle
        )
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

    // MARK: - Full scan tip

    private func buildFullScanTip() -> some View {
        TipView(fullScanTip) { action in
            if action.id == "full-scan" {
                viewModel.forceFullScan()
            }
        }
        .tipImageSize(CGSize(width: 20, height: 20))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Bitcoin action bar

    private func buildActionBar(isWatchOnly: Bool) -> some View {
        let hasTransactions = !viewModel.uiState.transactions.isEmpty
        let isSyncing = selectedWalletSyncState.isBusy
        return HStack(spacing: 12) {
            buildActionButton(title: "Receive", icon: "arrow.down.circle.fill", disabled: false) {
                viewModel.showReceiveAddress()
            }
            if !isWatchOnly {
                buildActionButton(title: "Send", icon: "arrow.up.circle.fill", disabled: isSyncing) {
                    viewModel.showSendSheet()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(hasTransactions ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
    }

    private func buildActionButton(title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? Color.blue.opacity(0.4) : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled)
    }

    // MARK: - Transaction list

    private func buildTransactionList() -> some View {
        WalletsTransactionsView(
            transactions: viewModel.uiState.transactions,
            isLoading: viewModel.uiState.isLoadingTransactions,
            syncState: selectedWalletSyncState
        )
    }

    /// Sync state of the currently selected wallet.
    private var selectedWalletSyncState: WalletSyncState {
        guard let id = viewModel.uiState.selectedWalletId else { return .idle }
        return viewModel.uiState.walletSyncStates[id] ?? .idle
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

    // MARK: - Permission sheet

    private func buildNotificationPermissionSheet() -> some View {
        PermissionRequestView(
            permissionType: .pushNotifications,
            onAllow: {
                Task {
                    let granted = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .badge, .sound])
                    if granted == true {
                        await MainActor.run {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                    await MainActor.run {
                        showNotificationPermission = false
                        viewModel.showAddWallet()
                    }
                }
            },
            onSkip: {
                showNotificationPermission = false
                viewModel.showAddWallet()
            }
        )
    }

    // MARK: - Sheets

    private func buildAddSheet() -> some View {
        AddWalletSheetView(viewModel: viewModel)
    }

    @ViewBuilder
    private func buildSettingsSheet() -> some View {
        if let wallet = selectedWallet {
            WalletSettingsSheet(wallet: wallet, viewModel: viewModel)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
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
                    viewModel.showWalletSettings()
                } label: {
                    Image(systemName: "gear")
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        let settings = await UNUserNotificationCenter.current().notificationSettings()
                        await MainActor.run {
                            if settings.authorizationStatus == .notDetermined {
                                showNotificationPermission = true
                            } else {
                                viewModel.showAddWallet()
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
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
