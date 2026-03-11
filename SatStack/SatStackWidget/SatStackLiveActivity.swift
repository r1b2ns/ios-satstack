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
        // No Spacers here — the two rows each use .frame(maxWidth: .infinity)
        // so they split the available width equally (each ~½ of total).
        // Mixing Spacers with maxWidth-infinity rows causes all four to compete
        // for the same space, leaving each row with only ¼ of the width.
        HStack(alignment: .top, spacing: 0) {
            buildBlockRow(side: .unconfirmed)

            // Divider: opacity raised to 0.35 so it remains visible on black.
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 1)
                .frame(height: 34 + 3 + 10) // block + spacing + indicator

            buildBlockRow(side: .confirmed)
        }
        .padding(.vertical, 14)
    }

    /// Renders 3 blocks for the given side with a position indicator chevron.
    ///
    /// **Left (unconfirmed):** chevron appears below the block matching the
    /// transaction's `blockPosition` in the mempool queue:
    /// - `nextBlock`   → index 2 (closest to the divider)
    /// - `secondBlock` → index 1 (middle)
    /// - `other` / nil → index 0 (farthest from confirmation)
    ///
    /// **Right (confirmed):** when `status == .confirmed`, chevron appears below
    /// the block at `confirmations - 1` (clamped to 0…2).
    func buildBlockRow(side: BlockSide) -> some View {
        // Each row fills exactly half the content width; blocks are centered.
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                VStack(spacing: 3) {
                    BlockView(side: side)

                    // Force both the chevron and the invisible placeholder to the
                    // same fixed height so both rows are always equally tall.
                    if showChevron(on: side, at: index) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(side == .confirmed ? Color.purple : Color.gray)
                            .frame(height: 10)
                    } else {
                        Color.clear.frame(height: 10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity) // content is auto-centered within the half-width frame
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

    /// Determines whether the position indicator chevron should appear
    /// for a specific block slot.
    private func showChevron(on side: BlockSide, at index: Int) -> Bool {
        let status        = context.state.status
        let confirmations = context.state.confirmations
        let position      = context.state.blockPosition

        switch side {

        // Left (gray) — shows where the tx sits in the mempool queue.
        // The rightmost block (index 2) is closest to the divider, i.e.
        // closest to being mined (nextBlock), so the mapping is inverted.
        case .unconfirmed:
            guard status == .pending else { return false }
            switch position {
            case .nextBlock:   return index == 2
            case .secondBlock: return index == 1
            case .other, nil:  return index == 0
            }

        // Right (purple) — shows which confirmed block the tx landed in.
        case .confirmed:
            guard status == .confirmed, confirmations > 0 else { return false }
            return index == min(confirmations - 1, 2)
        }
    }

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

// MARK: - Block Side

private enum BlockSide {
    case unconfirmed, confirmed
}

// MARK: - Block View

private struct BlockView: View {
    let side: BlockSide

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(side == .unconfirmed ? Color.gray.opacity(0.5) : Color.purple)
            .frame(width: 34, height: 34)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        side == .unconfirmed
                            ? Color.white.opacity(0.15)
                            : Color.purple.opacity(0.7),
                        lineWidth: 1
                    )
            )
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
