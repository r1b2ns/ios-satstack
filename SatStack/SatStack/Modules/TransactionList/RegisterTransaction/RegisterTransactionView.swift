import SwiftUI

struct RegisterTransactionView<ViewModel: RegisterTransactionViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                buildTxidField()
                buildPasteButton()
                buildWatchButton()
                buildStatusMessage()
                Spacer()
            }
            .padding(16)
            .navigationTitle("Watch Transaction")
            .onAppear { viewModel.checkClipboard() }
            .onChange(of: viewModel.uiState.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss { dismiss() }
            }
            .alert("Error", isPresented: $viewModel.uiState.isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = viewModel.uiState.errorMessage {
                    Text(message)
                }
            }
        }
    }

    // MARK: - Subviews

    private func buildTxidField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("Transaction ID", style: .subheadline, color: .secondary)

            TextField("Paste TXID here…", text: $viewModel.uiState.txid, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.footnote, design: .monospaced))
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
                    ProgressView().tint(.white)
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
        if viewModel.uiState.statusIsSuccess, !viewModel.uiState.statusMessage.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                AppText(viewModel.uiState.statusMessage, style: .subheadline, color: .custom(.green))
            }
            .foregroundStyle(Color.green)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.green.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

#Preview {
    RegisterTransactionView(viewModel: RegisterTransactionViewModel())
}
