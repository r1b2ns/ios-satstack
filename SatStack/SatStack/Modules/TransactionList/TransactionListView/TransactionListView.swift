import SwiftUI
import UserNotifications

// MARK: - Factory

struct TransactionListViewFactory {
    /// Module entry point.
    /// Returns a view that internally manages the lifecycle of the coordinator and viewModel.
    static func build() -> some View {
        TransactionListEntry()
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
private struct TransactionListEntry: View {
    @StateObject private var coordinator = TransactionListCoordinator()
    @StateObject private var viewModel   = TransactionListViewModel()

    var body: some View {
        TransactionListView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct TransactionListView<ViewModel: TransactionListViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: TransactionListCoordinator
    @Environment(\.openURL) private var openURL

    @State private var showNotificationPermission = false
    @State private var showNotificationDeniedAlert = false

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            buildContent()
                .navigationTitle("Watching")
                .toolbar { buildToolbar() }
                .sheet(isPresented: $coordinator.showRegisterTransaction) {
                    RegisterTransactionView(viewModel: RegisterTransactionViewModel())
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.automatic)
                }
                .sheet(isPresented: $showNotificationPermission) {
                    buildNotificationPermissionSheet()
                }
                .alert("Push Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("OK") {
                        coordinator.presentRegisterTransaction()
                    }
                } message: {
                    Text("You won't be notified when your transaction is confirmed. Enable notifications in Settings to stay updated.")
                }
                .onAppear { Task { await viewModel.loadTransactions() } }
                .onChange(of: coordinator.showRegisterTransaction) { _, isPresented in
                    if !isPresented {
                        Task { await viewModel.loadTransactions() }
                    }
                }
                .navigationDestinations()
        }
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
                        coordinator.presentRegisterTransaction()
                    }
                }
            },
            onSkip: {
                showNotificationPermission = false
                coordinator.presentRegisterTransaction()
            }
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private func buildContent() -> some View {
        if viewModel.uiState.isLoading && viewModel.uiState.transactions.isEmpty {
            buildLoadingView()
        } else if viewModel.uiState.transactions.isEmpty {
            buildEmptyView()
        } else {
            buildTransactionList()
        }
    }

    private func buildLoadingView() -> some View {
        ProgressView("Loading transactions…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func buildEmptyView() -> some View {
        ContentUnavailableView(
            "No transactions",
            systemImage: "magnifyingglass",
            description: Text("Tap + to start watching a transaction.")
        )
    }

    private func buildTransactionList() -> some View {
        List {
            buildSection(title: "Not Found", transactions: viewModel.uiState.notFoundTransactions)
            buildSection(title: "Pending", transactions: viewModel.uiState.pendingTransactions)
            buildSection(title: "Confirmed", transactions: viewModel.uiState.confirmedTransactions)
        }
        .refreshable {
            await viewModel.loadTransactions()
        }
    }

    @ViewBuilder
    private func buildSection(title: String, transactions: [WatchTransactionResponse]) -> some View {
        if !transactions.isEmpty {
            Section(title) {
                ForEach(transactions, id: \.txId) { transaction in
                    Button {
                        guard let url = BDKNetworkConfig.transactionURL(txid: transaction.txId) else { return }
                        openURL(url)
                    } label: {
                        buildTransactionRow(transaction)
                    }
                    .foregroundStyle(.foreground)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let txId = transactions[index].txId
                        Task { await viewModel.deleteTransaction(txId: txId) }
                    }
                }
            }
        }
    }

    private func buildTransactionRow(_ transaction: WatchTransactionResponse) -> some View {
        HStack(alignment: .center, spacing: 12) {
            buildRowLeftColumn(transaction)
            Spacer()
            buildRowRightColumn(
                transaction.status,
                isRefreshing: viewModel.uiState.isRefreshing(transaction.txId)
            )
        }
        .padding(.vertical, 4)
    }

    private func buildRowLeftColumn(_ transaction: WatchTransactionResponse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            buildValueLabel(transaction.valueBtc)
            buildTxIdLabel(transaction.txId)
            buildConfirmationsLabel(transaction.confirmations)
        }
    }

    private func buildRowRightColumn(_ status: TransactionStatus, isRefreshing: Bool) -> some View {
        HStack(spacing: 6) {
            buildStatusBadge(status)
            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.75)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 16, height: 16)
            }
        }
    }

    private func buildTxIdLabel(_ txId: String) -> some View {
        AppText(txId, style: .monospaced, color: .secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private func buildStatusBadge(_ status: TransactionStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending:   return .orange
            case .confirmed: return .green
            case .failed:    return .red
            case .notFound:  return .gray
            }
        }()
        return AppBadge(text: status.label, tint: color)
    }

    private func buildConfirmationsLabel(_ confirmations: Int) -> some View {
        AppText("\(confirmations) conf.", style: .caption, color: .secondary)
    }

    @ViewBuilder
    private func buildValueLabel(_ valueBtc: Double?) -> some View {
        if let valueBtc {
            BalanceDisplayFormatView(sats: UInt64(abs(valueBtc) * 100_000_000))
                .font(.body)
                .fontWeight(.semibold)
        } else {
            AppText("—", style: .body, color: .secondary)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    await MainActor.run {
                        switch settings.authorizationStatus {
                        case .notDetermined:
                            showNotificationPermission = true
                        case .denied:
                            showNotificationDeniedAlert = true
                        default:
                            coordinator.presentRegisterTransaction()
                        }
                    }
                }
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
        self.navigationDestination(for: TransactionListRoute.self) { route in
            switch route {
            case .detail(let txId):
                Text("Detail: \(txId)")
            }
        }
    }
}
