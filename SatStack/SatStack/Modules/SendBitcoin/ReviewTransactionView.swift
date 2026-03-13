import SwiftUI

// MARK: - ReviewTransactionView

/// Read-only summary of the composed Bitcoin transaction before broadcasting.
///
/// Shows recipient address, amount, network fee breakdown, and total cost.
/// The "Send" button is a placeholder until BDK transaction signing is wired up.
struct ReviewTransactionView<ViewModel: SendBitcoinViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: SendBitcoinCoordinator

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                buildContent()
                buildSendButton()
            }

            if viewModel.uiState.isBroadcasting {
                buildBroadcastingOverlay()
            }
        }
        .navigationTitle("Review Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onChange(of: viewModel.uiState.broadcastTxId) { _, txid in
            if txid != nil {
                coordinator.navigateToSuccess()
            }
        }
        .alert("Broadcast Failed", isPresented: $viewModel.uiState.isBroadcastError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = viewModel.uiState.errorMessage {
                Text(message)
            }
        }
    }

    // MARK: - Scrollable content

    private func buildContent() -> some View {
        ScrollView {
            VStack(spacing: 16) {
                buildRecipientCard()
                buildAmountCard()
                buildFeeCard()
                buildTotalCard()
                buildConfirmationHint()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Recipient

    private func buildRecipientCard() -> some View {
        buildCard(title: "To") {
            Text(viewModel.uiState.address)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Amount

    private func buildAmountCard() -> some View {
        buildCard(title: "Amount") {
            buildBalanceRow(label: "Value", sats: amountSats)
        }
    }

    // MARK: - Fee

    private func buildFeeCard() -> some View {
        buildCard(title: "Network Fee") {
            VStack(spacing: 10) {
                if let option = viewModel.uiState.selectedFee {
                    buildRow(
                        label: "Speed",
                        value: "\(option.title) · \(option.estimatedTime)"
                    )
                    buildRow(
                        label: "Rate",
                        value: feeRateText(for: option)
                    )
                    buildDivider()
                    if let feeSats = viewModel.estimatedFeeSats(for: option) {
                        buildBalanceRow(label: "Fee", sats: UInt64(feeSats))
                    }
                }
            }
        }
    }

    // MARK: - Total

    private func buildTotalCard() -> some View {
        buildCard(title: "Total") {
            buildBalanceRow(
                label: "Amount + Fee",
                sats: totalSats,
                bold: true
            )
        }
    }

    // MARK: - Confirmation hint

    @ViewBuilder
    private func buildConfirmationHint() -> some View {
        if let option = viewModel.uiState.selectedFee {
            Label("Estimated confirmation: \(option.estimatedTime)", systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Broadcasting overlay

    private func buildBroadcastingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Broadcasting...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Send button

    private func buildSendButton() -> some View {
        Button {
            Task { await viewModel.broadcastTransaction() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text("Send")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.uiState.isBroadcasting)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Reusable card

    private func buildCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reusable row

    private enum ValueStyle { case `default`, monospaced }

    private func buildRow(
        label: String,
        value: String,
        valueStyle: ValueStyle = .default,
        bold: Bool = false,
        secondary: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(secondary ? .clear : .secondary)
                .frame(minWidth: 80, alignment: .leading)

            Spacer()

            Text(value)
                .font(valueStyle == .monospaced
                      ? .system(.subheadline, design: .monospaced)
                      : .subheadline)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(secondary ? .secondary : .primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func buildDivider() -> some View {
        Divider()
    }

    // MARK: - Computed display values

    /// The entered amount converted to satoshis based on the user's preferred balance format.
    private var amountSats: UInt64 {
        let text = viewModel.uiState.amountText.replacingOccurrences(of: ",", with: ".")
        guard let rawValue = Double(text) else { return 0 }
        let amountBTC: Double
        switch UserDefaults.standard.preferredBalanceFormat {
        case .bitcoin, .fiat: amountBTC = rawValue
        case .sats, .bip177:  amountBTC = rawValue / 100_000_000.0
        }
        return UInt64(amountBTC * 100_000_000)
    }

    /// Total cost (amount + estimated fee) in satoshis.
    private var totalSats: UInt64 {
        guard let option = viewModel.uiState.selectedFee,
              let feeSats = viewModel.estimatedFeeSats(for: option) else { return amountSats }
        return amountSats + UInt64(feeSats)
    }

    private func feeRateText(for option: FeeOption) -> String {
        guard let rate = viewModel.feeRate(for: option) else { return "—" }
        return "\(rate) sat/vB"
    }

    // MARK: - Balance row

    /// Row that renders a satoshi amount in the user's preferred balance format.
    /// When the preference is `.fiat`, falls back to BTC since transaction
    /// amounts are denominated in bitcoin.
    private func buildBalanceRow(
        label: String,
        sats: UInt64,
        bold: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)

            Spacer()

            Text(formatSendAmount(sats))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(bold ? .semibold : .regular)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Formats satoshis for display in the Send Bitcoin context.
    /// When the user's preference is `.fiat`, falls back to BTC format
    /// since transaction amounts are denominated in bitcoin.
    private func formatSendAmount(_ sats: UInt64) -> String {
        let format = UserDefaults.standard.preferredBalanceFormat
        switch format {
        case .bitcoin, .fiat:
            let btc = Double(sats) / 100_000_000.0
            return String(format: "₿ %.8f", btc)
        case .sats:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: sats)) ?? "\(sats)") sats"
        case .bip177:
            return "\(sats.formattedBip177()) ₿"
        }
    }
}
