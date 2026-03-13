import ActivityKit
import WidgetKit
import SwiftUI

struct WalletSyncLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalletSyncActivityAttributes.self) { context in

            // Lock Screen / Notification Banner
            SyncLockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "satstack://wallets"))

        } dynamicIsland: { context in

            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    buildExpandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    SyncStatusBadge(status: context.state.status)
                }

                DynamicIslandExpandedRegion(.center) {
                    buildExpandedCenter(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    buildExpandedBottom(context: context)
                }

            } compactLeading: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .font(.caption)

            } compactTrailing: {
                buildCompactTrailing(context: context)

            } minimal: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .font(.caption2)
            }
            .keylineTint(.orange)
            .widgetURL(URL(string: "satstack://wallets"))
        }
    }

    // MARK: - Dynamic Island: Expanded

    private func buildExpandedLeading(
        context: ActivityViewContext<WalletSyncActivityAttributes>
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: context.state.isKyotoMode ? "network" : "arrow.triangle.2.circlepath")
                .foregroundStyle(.orange)
                .font(.title3)
            Text(context.state.isKyotoMode ? "Kyoto Sync" : "Wallet Sync")
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
        }
    }

    private func buildExpandedCenter(
        context: ActivityViewContext<WalletSyncActivityAttributes>
    ) -> some View {
        Group {
            if let name = context.state.currentWalletName {
                Text(name)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
    }

    private func buildExpandedBottom(
        context: ActivityViewContext<WalletSyncActivityAttributes>
    ) -> some View {
        HStack(spacing: 12) {
            Label(
                "\(context.state.completedWallets)/\(context.state.totalWallets)",
                systemImage: "creditcard"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if context.state.status == .fullScanning, let count = context.state.fullScanScriptCount {
                Label(
                    "\(count) scripts",
                    systemImage: "doc.text.magnifyingglass"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Dynamic Island: Compact Trailing

    private func buildCompactTrailing(
        context: ActivityViewContext<WalletSyncActivityAttributes>
    ) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(context.state.status.color)
                .frame(width: 6, height: 6)
            Text("\(context.state.completedWallets)/\(context.state.totalWallets)")
                .font(.caption2.monospacedDigit())
        }
    }
}

// MARK: - Lock Screen View

private struct SyncLockScreenView: View {
    let context: ActivityViewContext<WalletSyncActivityAttributes>

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
            HStack(spacing: 6) {
                Image(systemName: context.state.isKyotoMode ? "network" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Text("Wallet Sync")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(.white)

                if context.state.isKyotoMode {
                    Text("P2P")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
            }

            Spacer()

            Text("\(context.state.completedWallets) / \(context.state.totalWallets)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    func buildContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch context.state.status {
            case .syncing:
                buildSyncingContent()
            case .fullScanning:
                buildFullScanContent()
            case .completed:
                buildCompletedContent()
            case .failed:
                buildFailedContent()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func buildSyncingContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = context.state.currentWalletName {
                Text(name)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            buildProgressBar(progress: context.state.progress)
        }
    }

    private func buildFullScanContent() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                if let name = context.state.currentWalletName {
                    Text(name)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                if let count = context.state.fullScanScriptCount {
                    Text("\(count) scripts inspected")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.white)
                }
            }

            Spacer()
        }
    }

    private func buildCompletedContent() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            Text("All wallets synced")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func buildFailedContent() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync failed")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.red)
                if let error = context.state.errorMessage {
                    Text(error)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }

    // MARK: - Progress Bar

    private func buildProgressBar(progress: Double?) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 8)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Fill
                if let progress {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: max(8, proxy.size.width * CGFloat(min(progress, 1.0))),
                            height: 8
                        )
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    // Indeterminate — show a subtle pulsing bar
                    Capsule()
                        .fill(Color.orange.opacity(0.4))
                        .frame(width: proxy.size.width * 0.3, height: 8)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .frame(height: 16)
    }

    // MARK: - Footer

    func buildFooter() -> some View {
        HStack(spacing: 4) {
            Image(systemName: footerIcon)
                .font(.caption2)
                .foregroundStyle(footerColor)
            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if context.state.isWaitingBackground {
                Text("Waiting Network")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.8))
            }
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

    // MARK: - Footer Helpers

    private var footerText: String {
        let prefix = context.state.isKyotoMode ? "Kyoto — " : ""
        switch context.state.status {
        case .syncing:
            if let progress = context.state.progress {
                return "\(prefix)Syncing — \(Int(progress * 100))%"
            }
            return "\(prefix)Syncing wallets…"
        case .fullScanning:
            return "\(prefix)Full scan in progress…"
        case .completed:
            return "Sync complete"
        case .failed:
            return "Tap to view details"
        }
    }

    private var footerIcon: String {
        switch context.state.status {
        case .syncing, .fullScanning: return "clock"
        case .completed:              return "checkmark.circle.fill"
        case .failed:                 return "exclamationmark.triangle.fill"
        }
    }

    private var footerColor: Color {
        switch context.state.status {
        case .syncing, .fullScanning: return .secondary
        case .completed:              return .green
        case .failed:                 return .red
        }
    }
}

// MARK: - Status Badge

private struct SyncStatusBadge: View {
    let status: WalletSyncActivityStatus

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

// MARK: - Status Helpers

private extension WalletSyncActivityStatus {
    var color: Color {
        switch self {
        case .syncing:      return .orange
        case .fullScanning: return .teal
        case .completed:    return .green
        case .failed:       return .red
        }
    }

    var label: String {
        switch self {
        case .syncing:      return "Syncing"
        case .fullScanning: return "Scanning"
        case .completed:    return "Done"
        case .failed:       return "Failed"
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen — Syncing", as: .content, using: WalletSyncActivityAttributes(
    startedAt: Date()
)) {
    WalletSyncLiveActivity()
} contentStates: {
    WalletSyncActivityAttributes.ContentState(
        status: .syncing,
        progress: nil,
        fullScanScriptCount: nil,
        currentWalletName: "Main Wallet",
        completedWallets: 1,
        totalWallets: 3,
        errorMessage: nil
    )
    WalletSyncActivityAttributes.ContentState(
        status: .fullScanning,
        progress: nil,
        fullScanScriptCount: 1_234,
        currentWalletName: "Savings",
        completedWallets: 0,
        totalWallets: 2,
        errorMessage: nil
    )
    WalletSyncActivityAttributes.ContentState(
        status: .completed,
        progress: 1.0,
        fullScanScriptCount: nil,
        currentWalletName: nil,
        completedWallets: 3,
        totalWallets: 3,
        errorMessage: nil
    )
    WalletSyncActivityAttributes.ContentState(
        status: .failed,
        progress: nil,
        fullScanScriptCount: nil,
        currentWalletName: nil,
        completedWallets: 1,
        totalWallets: 3,
        errorMessage: "Connection timeout — Electrum server unreachable"
    )
}
