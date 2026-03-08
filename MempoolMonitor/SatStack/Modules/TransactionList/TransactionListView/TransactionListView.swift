import SwiftUI

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
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL

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
                .task { await viewModel.loadTransactions() }
                .onChange(of: coordinator.showRegisterTransaction) { _, isPresented in
                    if !isPresented {
                        Task { await viewModel.loadTransactions() }
                    }
                }
                .navigationDestinations()
        }
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
            case .pending:   return theme.colors.warning
            case .confirmed: return theme.colors.success
            case .failed:    return theme.colors.destructive
            }
        }()
        return AppBadge(text: status.label, tint: color)
    }

    private func buildConfirmationsLabel(_ confirmations: Int) -> some View {
        AppText("\(confirmations) conf.", style: .caption, color: .secondary)
    }

    private func buildValueLabel(_ valueBtc: Double?) -> some View {
        Group {
            if let valueBtc {
                AppText(String(format: "₿ %.8f", valueBtc), style: .body)
                    .fontWeight(.semibold)
            } else {
                AppText("₿ —", style: .body, color: .secondary)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                coordinator.presentRegisterTransaction()
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
