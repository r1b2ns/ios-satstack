import ActivityKit
import WidgetKit
import SwiftUI

struct SatStackLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransactionActivityAttributes.self) { context in

            // ── Lock Screen / Notification Banner ─────────────────────────
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in

            DynamicIsland {
                // ── Expanded ───────────────────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        Text(context.state.txId.txTruncated())
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    StatusBadge(status: context.state.status)
                }

                DynamicIslandExpandedRegion(.center) {
                    if let btc = context.state.valueBtc {
                        Text(btc.balanceFormatted)
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.primary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Label("\(context.state.confirmations)", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(context.state.status.color)

                        if let fee = context.state.feeSats {
                            Label("\(fee) sats", systemImage: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

            } compactLeading: {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)

            } compactTrailing: {
                HStack(spacing: 3) {
                    Circle()
                        .fill(context.state.status.color)
                        .frame(width: 6, height: 6)
                    Text("\(context.state.confirmations)")
                        .font(.caption2.monospacedDigit())
                }

            } minimal: {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
            }
            .keylineTint(.orange)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<TransactionActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            buildHeader()
            buildSeparator()
            buildContent()
            buildSeparator()
            buildFooter()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    func buildHeader() -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                // Sender address above the BTC value
                if let address = context.state.senderAddress {
                    Text(address.txTruncated(chars: 8))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if let btc = context.state.valueBtc {
                    Text(btc.balanceFormatted)
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundStyle(.white)
                } else {
                    Text("–")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            if let fee = context.state.feeSats {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(fee) sats")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    func buildContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            buildProgressLabels()
            buildProgressBar()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    func buildProgressLabels() -> some View {
        HStack {
            Text("Unconfirmed")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text("Confirmed")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    func buildProgressBar() -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                buildGradientTrack()
                buildMidpointDivider(in: proxy)
                buildIndicator(in: proxy)
            }
        }
        .frame(height: 16)
    }

    private func buildGradientTrack() -> some View {
        Capsule()
            .fill(LinearGradient(
                colors: [.green, .teal, .indigo, .purple],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: 8)
            .frame(maxHeight: .infinity, alignment: .center)
    }

    private func buildMidpointDivider(in proxy: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.45))
            .frame(width: 2, height: 16)
            .frame(maxHeight: .infinity, alignment: .center)
            .offset(x: proxy.size.width / 2 - 1)
    }

    private func buildIndicator(in proxy: GeometryProxy) -> some View {
        let position = indicatorProgress * proxy.size.width
        return Circle()
            .fill(.white)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
            .frame(width: 16, height: 16)
            .offset(x: position - 8)
    }

    // MARK: - Progress

    /// Maps the transaction state to a 0.0–1.0 position along the gradient bar.
    ///
    /// The bar is split at 0.5 (midpoint divider):
    ///   - Left  (0.0–0.5): unconfirmed zone — indicator never crosses 0.5 while pending
    ///   - Right (0.5–1.0): confirmed zone   — indicator enters only after confirmation
    ///
    /// Each half contains 3 equal slots (mirroring the old block grid):
    ///   - Unconfirmed: other (1/12) → secondBlock (3/12) → nextBlock (5/12)
    ///   - Confirmed:   1 conf (7/12) → 2 conf (9/12) → 3+ conf (11/12)
    private var indicatorProgress: Double {
        switch context.state.status {
        case .pending:
            switch context.state.blockPosition {
            case .nextBlock:   return 5.0 / 12.0   // ~0.417 — right edge of left half
            case .secondBlock: return 3.0 / 12.0   // 0.25   — centre of left half
            case .other, nil:  return 1.0 / 12.0   // ~0.083 — far left
            }
        case .confirmed:
            guard context.state.confirmations > 0 else { return 7.0 / 12.0 }
            let slot = min(context.state.confirmations - 1, 2)
            return (7.0 + Double(slot) * 2.0) / 12.0  // 7/12, 9/12, 11/12
        case .failed, .notFound:
            return 1.0 / 12.0
        }
    }

    // MARK: - Footer

    func buildFooter() -> some View {
        let confirmed = context.state.status == .confirmed
        return HStack(spacing: 4) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "clock")
                .font(.caption2)
                .foregroundStyle(confirmed ? Color.purple : Color.secondary)
            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Separator

    func buildSeparator() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }

    // MARK: - Helpers

    private var footerText: String {
        switch context.state.status {
        case .pending:
            if let minutes = context.state.estimatedMinutes {
                return "~\(minutes) min until confirmation"
            }
            return "Awaiting confirmation"
        case .confirmed:
            return "Transaction confirmed"
        case .failed:
            return "Transaction failed"
        case .notFound:
            return "Transaction not found"
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: TransactionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
            Text(status.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Helpers

private extension TransactionStatus {
    var color: Color {
        switch self {
        case .pending:   return .orange
        case .confirmed: return .purple
        case .failed:    return .red
        case .notFound:  return .gray
        }
    }
}

private extension Double {
    /// Formats a BTC value using the user's preferred balance display format.
    ///
    /// Reads `UserDefaults.standard` with the same key as the main app.
    /// Falls back to BTC format for the `.fiat` case, since price data
    /// is not available in the widget extension.
    var balanceFormatted: String {
        let sats = UInt64(abs(self) * 100_000_000)
        switch UserDefaults.standard.string(forKey: "preferredBalanceFormat") {
        case "sats":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: sats)) ?? "\(sats)") sats"
        case "bip177":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: sats)) ?? "\(sats)") ₿"
        default: // "bitcoin", "fiat" (no price data in widget), or unset → BTC
            let s = String(format: "%.8f", abs(self))
            let trimmed = s
                .replacingOccurrences(of: "(\\.[0-9]*[1-9])0+$", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "\\.0+$",               with: ".0",  options: .regularExpression)
            return "\(trimmed) BTC"
        }
    }
}

private extension String {
    /// Displays the first and last N characters of a hash/address separated by "…".
    func txTruncated(chars: Int = 6) -> String {
        guard count > chars * 2 + 1 else { return self }
        return "\(prefix(chars))…\(suffix(chars))"
    }
}

// MARK: - Preview

#Preview("Lock Screen — nextBlock", as: .content, using: TransactionActivityAttributes(
    txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7"
)) {
    SatStackLiveActivity()
} contentStates: {
    // Pending — far from confirmation
    TransactionActivityAttributes.ContentState(
        confirmations: 0,
        status: .pending,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119,
        estimatedMinutes: 30,
        senderAddress: "bc1qxy2kgdygjrsqtzq2n0yrf249pk4sg5tfpd0ath",
        blockPosition: .other
    )
    // Pending — second block
    TransactionActivityAttributes.ContentState(
        confirmations: 0,
        status: .pending,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119,
        estimatedMinutes: 20,
        senderAddress: "bc1qxy2kgdygjrsqtzq2n0yrf249pk4sg5tfpd0ath",
        blockPosition: .secondBlock
    )
    // Pending — next block
    TransactionActivityAttributes.ContentState(
        confirmations: 0,
        status: .pending,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119,
        estimatedMinutes: 10,
        senderAddress: "bc1qxy2kgdygjrsqtzq2n0yrf249pk4sg5tfpd0ath",
        blockPosition: .nextBlock
    )
    // Confirmed — 1st block
    TransactionActivityAttributes.ContentState(
        confirmations: 1,
        status: .confirmed,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119,
        estimatedMinutes: nil,
        senderAddress: "bc1qxy2kgdygjrsqtzq2n0yrf249pk4sg5tfpd0ath",
        blockPosition: nil
    )
    // Confirmed — 3rd block
    TransactionActivityAttributes.ContentState(
        confirmations: 3,
        status: .confirmed,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119,
        estimatedMinutes: nil,
        senderAddress: "bc1qxy2kgdygjrsqtzq2n0yrf249pk4sg5tfpd0ath",
        blockPosition: nil
    )
}
