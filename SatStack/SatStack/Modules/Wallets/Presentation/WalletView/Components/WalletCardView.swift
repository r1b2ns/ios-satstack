import SwiftUI

/// Apple Wallet-style card that represents a single wallet entry.
///
/// Displays the wallet theme icon and type badge at the top,
/// and the wallet name with BTC balance at the bottom.
///
/// The balance is **always visible** — when no live balance is available
/// the card falls back to the last persisted `wallet.balanceBTC`.
/// The top-right badge shows a circular progress indicator during sync
/// (determinate with percentage for incremental, indeterminate spinner
/// for full scans).
///
/// - Parameters:
///   - wallet: The wallet data to display.
///   - balanceSats: Live balance in satoshis fetched from the chain.
///     When `nil`, falls back to `wallet.balanceBTC`.
///   - syncState: Current sync lifecycle. Controls the top-right badge.
struct WalletCardView: View {

    let wallet: Wallet
    var balanceSats: UInt64? = nil
    var syncState: WalletSyncState = .idle
    var isKyotoConnected: Bool = false

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

    /// Top-right badge — shows queue/sync status, error icon, or theme name.
    @ViewBuilder
    private func buildStatusBadge() -> some View {
        switch syncState {
        case .queued:
            buildQueuedBadge()
        case .syncing(let progress):
            buildSyncProgressBadge(progress: progress)
        case .fullScanning(let count):
            buildFullScanBadge(count: count)
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

    /// Badge shown when the wallet is waiting in the sequential sync queue.
    private func buildQueuedBadge() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
            Text("QUEUED")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.5)
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    /// Badge shown during a full BIP-84 scan, displaying the running script count
    /// alongside an indeterminate progress spinner.
    private func buildFullScanBadge(count: UInt64) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.9))
                .controlSize(.mini)

            Text("SYNCING(\(count))")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)
                .monospacedDigit()
        }
    }

    /// Circular progress indicator with percentage text for determinate syncs,
    /// or a spinning partial ring for indeterminate (full scan) syncs.
    private func buildSyncProgressBadge(progress: Double?) -> some View {
        HStack(spacing: 6) {
            ZStack {
                // Track circle (background ring).
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)

                if let progress {
                    // Determinate: filled arc proportional to progress.
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    // Indeterminate: spinning partial arc.
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(indeterminateRotation)
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                indeterminateRotation = .degrees(360)
                            }
                        }
                }
            }
            .frame(width: 16, height: 16)

            if let progress {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            } else {
                Text("SYNCING")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1.5)
            }
        }
    }

    /// Continuous rotation angle for the indeterminate spinner.
    @State private var indeterminateRotation: Angle = .zero

    private func buildBalanceSection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                buildConnectionIndicator()
                Text(wallet.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
            }
            buildBalanceRow()
        }
    }

    /// Small dot indicating the Kyoto P2P connection status for this wallet.
    private func buildConnectionIndicator() -> some View {
        Circle()
            .fill(isKyotoConnected ? Color.green : Color.white.opacity(0.4))
            .frame(width: 8, height: 8)
            .opacity(isKyotoConnected ? connectionPulse : 1)
            .animation(
                isKyotoConnected
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isKyotoConnected
            )
            .onAppear {
                if isKyotoConnected { connectionPulse = 0.5 }
            }
            .onChange(of: isKyotoConnected) { connected in
                connectionPulse = connected ? 0.5 : 1
            }
    }

    /// Opacity value used for the pulse animation on the connection dot.
    @State private var connectionPulse: Double = 1

    /// Balance is always displayed — never hidden behind a spinner.
    private func buildBalanceRow() -> some View {
        BalanceDisplayFormatView(sats: effectiveSats)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }

    // MARK: - Helpers

    /// The balance to display, in satoshis.
    /// Falls back to the last persisted `wallet.balanceBTC` when no live balance is available.
    private var effectiveSats: UInt64 {
        if let sats = balanceSats { return sats }
        return UInt64(wallet.balanceBTC * 100_000_000)
    }
}

