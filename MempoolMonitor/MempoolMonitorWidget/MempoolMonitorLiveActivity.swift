import ActivityKit
import WidgetKit
import SwiftUI

struct MempoolMonitorLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransactionActivityAttributes.self) { context in

            // ── Lock Screen / Notification Banner ─────────────────────────
            LockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)

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
                        Text(btc.btcFormatted)
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.primary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Confirmations
                        Label("\(context.state.confirmations)", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(context.state.status.color)

                        // Fee
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
        VStack(spacing: 10) {
            // ── Top row: icon + TXID + status ────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.txId.txTruncated())
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(1)
                    StatusBadge(status: context.state.status)
                }

                Spacer()

                // Confirmations
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(context.state.confirmations)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(context.state.status.color)
                    Text("confirm.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // ── Bottom row: value + fee ──────────────────────────────────
            HStack {
                // Value in BTC
                if let btc = context.state.valueBtc {
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(btc.btcFormatted)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Spacer()

                // Fee in sats
                if let fee = context.state.feeSats {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(fee) sats")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        case .confirmed: return .green
        case .failed:    return .red
        }
    }
}

private extension Double {
    /// Formats a BTC value removing unnecessary trailing zeros.
    /// Ex.: 0.07250000 → "0.0725 BTC" | 1.00000000 → "1.0 BTC"
    var btcFormatted: String {
        let s = String(format: "%.8f", self)
        let trimmed = s
            .replacingOccurrences(of: "(\\.[0-9]*[1-9])0+$", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\.0+$",              with: ".0",  options: .regularExpression)
        return "\(trimmed) BTC"
    }
}

private extension String {
    /// Displays the first and last N characters of the TXID separated by "…".
    /// Ex.: "abcd1234…ef567890"
    func txTruncated(chars: Int = 6) -> String {
        guard count > chars * 2 + 1 else { return self }
        return "\(prefix(chars))…\(suffix(chars))"
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: TransactionActivityAttributes(
    txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7"
)) {
    MempoolMonitorLiveActivity()
} contentStates: {
    TransactionActivityAttributes.ContentState(
        confirmations: 0,
        status: .pending,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119
    )
    TransactionActivityAttributes.ContentState(
        confirmations: 3,
        status: .confirmed,
        txId: "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7",
        valueBtc: 0.07250000,
        feeSats: 7_119
    )
}
