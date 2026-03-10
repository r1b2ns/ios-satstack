import SwiftUI

// MARK: - Mempool transaction URL helper

private extension WalletTransaction {

    /// Full mempool.space URL for this transaction, network-aware.
    var mempoolURL: URL? {
        BDKNetworkConfig.transactionURL(txid: address)
    }
}

// MARK: - WalletsTransactionsView

/// Displays the transaction list for the currently selected wallet.
///
/// Shows different states depending on the data and sync lifecycle:
/// - Syncing with no cached data → spinner + message
/// - Empty and not syncing → empty state
/// - Populated → transaction rows with optional refreshing indicator
struct WalletsTransactionsView: View {

    let transactions: [WalletTransaction]
    let isLoading: Bool
    let syncState: WalletSyncState

    @Environment(\.openURL) private var openURL

    private var isBusy: Bool { syncState.isBusy }
    private var hasContent: Bool { isLoading || !transactions.isEmpty || isBusy }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasContent {
                buildTransactionHeader()
            }
            buildTransactionRows()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
    }

    // MARK: - Header

    private func buildTransactionHeader() -> some View {
        Text("Latest Transactions")
            .font(.title3)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    // MARK: - Rows

    @ViewBuilder
    private func buildTransactionRows() -> some View {
        if isLoading && transactions.isEmpty {
            buildSyncingState()
        } else if transactions.isEmpty && !isBusy {
            buildEmptyState()
        } else if transactions.isEmpty && isBusy {
            buildSyncingState()
        } else {
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                buildTransactionRow(tx)
                if index < transactions.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
            if isBusy {
                buildRefreshingIndicator()
            }
        }
    }

    // MARK: - Transaction row

    private func buildTransactionRow(_ tx: WalletTransaction) -> some View {
        Button {
            guard let url = tx.mempoolURL else { return }
            openURL(url)
        } label: {
            HStack(spacing: 6) {
                buildTransactionIcon(isReceived: tx.isReceived)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tx.address)
                        .truncationMode(.middle)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(tx.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                buildTransactionValue(tx)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(tx.isConfirmed ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }

    private func buildTransactionValue(_ tx: WalletTransaction) -> some View {
        let sats = UInt64(abs(tx.valueBTC) * 100_000_000)
        return HStack(spacing: 2) {
            Text(tx.isReceived ? "+" : "−")
            BalanceDisplayFormatView(sats: sats)
        }
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(tx.isReceived ? Color.green : Color.red)
    }

    private func buildTransactionIcon(isReceived: Bool) -> some View {
        Image(systemName: isReceived ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
            .font(.title3)
            .foregroundStyle(isReceived ? Color.green : Color.red)
            .frame(width: 32)
    }

    // MARK: - States

    private func buildSyncingState() -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Syncing wallet...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Text("Transactions will appear once the sync completes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }

    private func buildRefreshingIndicator() -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Refreshing transactions...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func buildEmptyState() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("No transactions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
