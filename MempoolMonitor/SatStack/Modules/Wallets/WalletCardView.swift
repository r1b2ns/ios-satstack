import SwiftUI

/// Apple Wallet-style card that represents a single wallet entry.
///
/// Displays the wallet theme icon and type badge at the top,
/// and the wallet name with BTC balance at the bottom.
///
/// - Parameters:
///   - wallet: The wallet data to display.
///   - balanceSats: Live balance in satoshis fetched from the chain.
///     When `nil` and `syncState == .syncing`, the card shows a spinner.
///     When `nil` and not syncing, falls back to `wallet.balanceBTC`.
///   - syncState: Current sync lifecycle. Controls the top-right badge
///     and the balance loading indicator.
struct WalletCardView: View {

    let wallet: Wallet
    var balanceSats: UInt64? = nil
    var syncState: WalletSyncState = .idle

    var body: some View {
        ZStack(alignment: .topLeading) {
            buildBackground()
            buildContent()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    // MARK: - Builders

    private func buildBackground() -> some View {
        wallet.theme.gradient
    }

    private func buildContent() -> some View {
        VStack(alignment: .leading) {
            buildTopRow()
            Spacer()
            buildBalanceSection()
        }
        .padding(24)
    }

    private func buildTopRow() -> some View {
        HStack(alignment: .top) {
            Image(systemName: wallet.theme.systemImage)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            buildStatusBadge()
        }
    }

    /// Top-right badge — shows sync progress or the theme name.
    @ViewBuilder
    private func buildStatusBadge() -> some View {
        switch syncState {
        case .syncing:
            HStack(spacing: 5) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.65)
                Text("SYNCING")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1.5)
            }
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                Text("SYNC ERROR")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.5)
            }
            .foregroundStyle(.white.opacity(0.7))
        case .idle, .synced:
            Text(wallet.theme.displayName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)
        }
    }

    private func buildBalanceSection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wallet.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
            buildBalanceRow()
        }
    }

    @ViewBuilder
    private func buildBalanceRow() -> some View {
        if syncState == .syncing && balanceSats == nil {
            // Balance not yet available — show spinner while syncing.
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.85)
                Text("Syncing…")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            Text("₿ \(formattedBalance)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private var formattedBalance: String {
        if let sats = balanceSats {
            return String(format: "%.8f", Double(sats) / 100_000_000.0)
        }
        return String(format: "%.8f", wallet.balanceBTC)
    }
}
