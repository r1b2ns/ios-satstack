import SwiftUI

struct RegisterTransactionView<ViewModel: RegisterTransactionViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @ObservedObject var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.shape.spacingXL) {
                buildTxidField()
                buildPasteButton()
                buildWatchButton()
                buildStatusMessage()
                Spacer()
            }
            .padding(theme.shape.spacingL)
            .navigationTitle("Watch Transaction")
            .onAppear { viewModel.checkClipboard() }
            .onChange(of: viewModel.uiState.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss { dismiss() }
            }
        }
    }

    // MARK: - Subviews

    private func buildTxidField() -> some View {
        VStack(alignment: .leading, spacing: theme.shape.spacingS) {
            AppText("Transaction ID", style: .subheadline, color: .secondary)

            TextField("Paste TXID here…", text: $viewModel.uiState.txid, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(theme.typography.monospaced)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .lineLimit(3...6)
                .submitLabel(.done)
        }
    }

    private func buildPasteButton() -> some View {
        Button {
            viewModel.pasteFromClipboard()
            viewModel.checkClipboard()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                Text("Paste")
            }
        }
        .buttonStyle(.appSecondary)
        .disabled(!viewModel.uiState.clipboardHasContent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildWatchButton() -> some View {
        Button {
            Task { await viewModel.watchTransaction() }
        } label: {
            HStack {
                if viewModel.uiState.isLoading {
                    ProgressView().tint(theme.colors.accentForeground)
                }
                Text(viewModel.uiState.isLoading ? "Sending…" : "Watch Transaction")
            }
        }
        .buttonStyle(.appPrimary)
        .disabled(
            viewModel.uiState.txid.trimmingCharacters(in: .whitespaces).isEmpty
            || viewModel.uiState.isLoading
        )
    }

    @ViewBuilder
    private func buildStatusMessage() -> some View {
        if !viewModel.uiState.statusMessage.isEmpty {
            let color: Color = viewModel.uiState.statusIsSuccess
                ? theme.colors.success
                : theme.colors.destructive

            HStack(spacing: theme.shape.spacingS) {
                Image(systemName: viewModel.uiState.statusIsSuccess
                      ? "checkmark.circle.fill"
                      : "xmark.circle.fill")
                AppText(viewModel.uiState.statusMessage, style: .subheadline, color: .custom(color))
            }
            .foregroundStyle(color)
            .padding(theme.shape.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                color.opacity(0.1),
                in: RoundedRectangle(cornerRadius: theme.shape.cornerRadiusSmall)
            )
        }
    }
}

#Preview {
    RegisterTransactionView(viewModel: RegisterTransactionViewModel())
}
