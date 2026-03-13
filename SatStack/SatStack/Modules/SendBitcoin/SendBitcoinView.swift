import SwiftUI

// MARK: - Factory

struct SendBitcoinViewFactory {

    /// Module entry point — manages coordinator and viewModel lifecycle internally.
    /// - Parameters:
    ///   - wallet: The wallet to send from.
    ///   - onTransactionSent: Called after a successful broadcast so the caller
    ///     can trigger a wallet sync or refresh.
    static func build(wallet: Wallet, onTransactionSent: @escaping () -> Void = {}) -> some View {
        SendBitcoinEntry(wallet: wallet, onTransactionSent: onTransactionSent)
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
private struct SendBitcoinEntry: View {

    @StateObject private var coordinator = SendBitcoinCoordinator()
    @StateObject private var viewModel: SendBitcoinViewModel
    @Environment(\.dismiss) private var dismiss

    let onTransactionSent: () -> Void

    init(wallet: Wallet, onTransactionSent: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SendBitcoinViewModel(wallet: wallet))
        self.onTransactionSent = onTransactionSent
    }

    var body: some View {
        SendBitcoinView(viewModel: viewModel)
            .environmentObject(coordinator)
            .onChange(of: viewModel.uiState.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    onTransactionSent()
                    dismiss()
                }
            }
    }
}

// MARK: - View

/// Screen for composing a Bitcoin transaction: recipient address, amount, and fee selection.
struct SendBitcoinView<ViewModel: SendBitcoinViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: SendBitcoinCoordinator
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable { case address, amount }
    @FocusState private var focusedField: Field?

    @State private var amountFormat: BalanceDisplayFormat = UserDefaults.standard.preferredBalanceFormat
    @State private var prices: PricesResponse?

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            buildContent()
                .navigationTitle("Send Bitcoin")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .fullScreenCover(isPresented: $viewModel.uiState.isPresentingScanner) {
                    QRScannerView { code in
                        viewModel.handleScannedCode(code)
                    }
                }
                .navigationDestination(for: SendBitcoinRoute.self) { route in
                    switch route {
                    case .reviewTransaction:
                        ReviewTransactionView(viewModel: viewModel)
                    case .transactionSuccess:
                        FeedbackView(
                            image: Image(systemName: "checkmark.circle.fill"),
                            title: "Transaction Sent",
                            subtitle: viewModel.uiState.broadcastTxId,
                            buttonTitle: "OK"
                        ) {
                            viewModel.uiState.shouldDismiss = true
                        }
                        .navigationBarBackButtonHidden()
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.loadFees() }
    .task { await loadPrices() }
    }

    // MARK: - Content

    private func buildContent() -> some View {
        VStack(spacing: 0) {
            buildForm()
            buildReviewButton()
        }
    }

    // MARK: - Form

    private func buildForm() -> some View {
        Form {
            buildRecipientSection()
            buildAmountSection()
            buildFeeSection()
            buildSummarySection()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Recipient section

    private func buildRecipientSection() -> some View {
        Section {
            buildAddressField()
        } header: {
            Text("Recipient")
        } footer: {
            buildAddressValidationHint()
        }
    }

    private func buildAddressField() -> some View {
        HStack(spacing: 12) {
            TextField("Bitcoin address", text: $viewModel.uiState.address)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1)
                .focused($focusedField, equals: .address)

            if !viewModel.uiState.address.isEmpty {
                buildClearButton()
            }

            buildPasteButton()
            buildScanButton()
        }
    }

    @ViewBuilder
    private func buildAddressValidationHint() -> some View {
        if let hint = viewModel.addressValidationHint {
            Label(hint, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func buildClearButton() -> some View {
        Button {
            viewModel.uiState.address = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func buildPasteButton() -> some View {
        Button {
            viewModel.pasteAddress()
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.body)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }

    private func buildScanButton() -> some View {
        Button {
            viewModel.uiState.isPresentingScanner = true
        } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.body)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount section

    private func buildAmountSection() -> some View {
        Section {
            buildAmountField()
        } header: {
            Text("Amount")
        } footer: {
            buildAmountFooter()
        }
    }

    private func buildAmountField() -> some View {
        HStack {
            TextField(amountPlaceholder, text: $viewModel.uiState.amountText)
                .font(.system(.body, design: .monospaced))
                .keyboardType(amountKeyboardType)
                .focused($focusedField, equals: .amount)

            Text(amountUnitLabel)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let newFormat = UserDefaults.standard.preferredBalanceFormat
            if amountFormat != newFormat {
                amountFormat = newFormat
                viewModel.uiState.amountText = ""
            }
        }
    }

    private var amountPlaceholder: String {
        switch amountFormat {
        case .bitcoin, .fiat: return "0.00000000"
        case .sats, .bip177:  return "0"
        }
    }

    private var amountUnitLabel: String {
        switch amountFormat {
        case .bitcoin, .fiat: return "BTC"
        case .sats:           return "sats"
        case .bip177:         return "₿"
        }
    }

    private var amountKeyboardType: UIKeyboardType {
        switch amountFormat {
        case .bitcoin, .fiat: return .decimalPad
        case .sats, .bip177:  return .numberPad
        }
    }

    @ViewBuilder
    private func buildAmountFooter() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Available:")
                BalanceDisplayFormatView(sats: UInt64(viewModel.wallet.balanceBTC * 100_000_000))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if viewModel.isAmountExceedsBalance {
                Label("Amount exceeds available balance", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if viewModel.isInsufficientFundsWithFee {
                Label("Insufficient funds to cover amount + fee", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Fee section

    private func buildFeeSection() -> some View {
        Section {
            buildFeePicker()
        } header: {
            buildFeeHeader()
        }
    }

    private func buildFeeHeader() -> some View {
        HStack(spacing: 12) {
            Text("Network Fee")
            
            Button {
                viewModel.uiState.isPresentingFeeInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $viewModel.uiState.isPresentingFeeInfo) {
                buildFeeInfoSheet()
            }
        }
    }

    private func buildFeePicker() -> some View {
        HStack(spacing: 10) {
            ForEach(FeeOption.allCases) { option in
                buildFeeCard(option)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    private func buildFeeCard(_ option: FeeOption) -> some View {
        let isSelected = viewModel.uiState.selectedFee == option
        let rate = viewModel.feeRate(for: option)
        let estimatedSats = viewModel.estimatedFeeSats(for: option)

        return Button {
            focusedField = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.uiState.selectedFee = option
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text(option.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                buildFeeRateLabel(rate: rate)
                buildEstimatedSatsLabel(sats: estimatedSats)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.blue : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func buildFeeRateLabel(rate: Int?) -> some View {
        if let rate {
            Text("\(rate) sat/vB")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if viewModel.uiState.isLoadingFees {
            ProgressView()
                .controlSize(.mini)
        } else {
            Text("—")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func buildEstimatedSatsLabel(sats: Int?) -> some View {
        if let sats {
            Text("≈ \(sats.formatted()) sats")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Fee info sheet

    private func buildFeeInfoSheet() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    buildFeeInfoSection(
                        icon: "bitcoinsign.circle.fill",
                        title: "What is a transaction fee?",
                        text: "Every Bitcoin transaction requires a fee paid to miners who validate and include it in a block. This fee is not set by any company — it is determined by supply and demand for block space."
                    )

                    buildFeeInfoSection(
                        icon: "scalemass.fill",
                        title: "How is the fee calculated?",
                        text: "The fee depends on the transaction's size in virtual bytes (vB), not the amount being sent. A typical transaction is around 140 vB. The total fee equals the fee rate (sat/vB) multiplied by the transaction size."
                    )

                    buildFeeInfoSection(
                        icon: "speedometer",
                        title: "Why are there different speeds?",
                        text: "Miners prioritize transactions with higher fees. Choosing a higher fee rate means your transaction is more likely to be confirmed in the next block (~10 minutes). Lower fees save money but may take longer to confirm."
                    )

                    buildFeeInfoSection(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Why do fees change?",
                        text: "Fee rates fluctuate based on network congestion. When many people are transacting, competition for block space increases and fees rise. During quieter periods, fees drop."
                    )
                }
                .padding()
            }
            .navigationTitle("Network Fees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.uiState.isPresentingFeeInfo = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func buildFeeInfoSection(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Summary section

    @ViewBuilder
    private func buildSummarySection() -> some View {
        if let selectedFee = viewModel.uiState.selectedFee,
           let feeSats = viewModel.estimatedFeeSats(for: selectedFee),
           let amountBTC = parsedAmountBTC,
           amountBTC > 0 {
            let amountSats = UInt64(amountBTC * 100_000_000)
            let totalSats = amountSats + UInt64(feeSats)

            Section {
                buildSummaryBalanceRow(label: "Amount", sats: amountSats)
                buildSummaryBalanceRow(label: "Fee", sats: UInt64(feeSats))
                buildTotalFiatRow(sats: totalSats)
                buildSummaryBalanceRow(label: "Total", sats: totalSats, bold: true)
            } header: {
                Text("Summary")
            }
        }
    }

    private func buildSummaryBalanceRow(label: String, sats: UInt64, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatSendAmount(sats))
                .font(.system(.body, design: .monospaced))
                .fontWeight(bold ? .semibold : .regular)
        }
    }

    /// Shows the total transaction value in the user's preferred fiat currency.
    @ViewBuilder
    private func buildTotalFiatRow(sats: UInt64) -> some View {
        let currency = UserDefaults.standard.preferredFiatCurrency
        if let prices {
            let btc = Double(sats) / 100_000_000.0
            let fiatValue = btc * currency.price(from: prices)
            HStack {
                Text("Total Fiat")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currency.formattedPrice(fiatValue))
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    /// Formats satoshis for display in the Send Bitcoin context.
    /// When the user's preference is `.fiat`, falls back to BTC format
    /// since transaction amounts are denominated in bitcoin.
    private func formatSendAmount(_ sats: UInt64) -> String {
        switch amountFormat {
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

    private func loadPrices() async {
        prices = try? await SwiftDataStorable.shared.fetch(
            PricesResponse.self,
            id: "bitcoin_prices"
        )
    }

    private var parsedAmountBTC: Double? {
        let text = viewModel.uiState.amountText.replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty, let value = Double(text) else { return nil }
        switch amountFormat {
        case .bitcoin, .fiat: return value
        case .sats, .bip177:  return value / 100_000_000.0
        }
    }

    // MARK: - Review button (bottom, styled like Receive/Send)

    private func buildReviewButton() -> some View {
        Button {
            coordinator.navigateToReview()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                Text("Review Transaction")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.isFormValid ? Color.blue : Color.blue.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.isFormValid)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

