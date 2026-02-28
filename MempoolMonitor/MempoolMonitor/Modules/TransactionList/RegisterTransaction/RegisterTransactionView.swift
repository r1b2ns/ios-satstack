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
            .padding()
            .navigationTitle("Watch Transaction")
            .onAppear { viewModel.checkClipboard() }
            .onChange(of: viewModel.uiState.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss { dismiss() }
            }
        }
    }

    // MARK: - Subviews

    private func buildTxidField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transaction ID")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .buttonStyle(.bordered)
        .disabled(!viewModel.uiState.clipboardHasContent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildWatchButton() -> some View {
        Button {
            Task { await viewModel.watchTransaction() }
        } label: {
            HStack {
                if viewModel.uiState.isLoading { ProgressView().tint(.white) }
                Text(viewModel.uiState.isLoading ? "Sending…" : "Watch Transaction")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(
            viewModel.uiState.txid.trimmingCharacters(in: .whitespaces).isEmpty
            || viewModel.uiState.isLoading
        )
    }

    @ViewBuilder
    private func buildStatusMessage() -> some View {
        if !viewModel.uiState.statusMessage.isEmpty {
            let color: Color = viewModel.uiState.statusIsSuccess ? .green : .red
            HStack(spacing: 8) {
                Image(systemName: viewModel.uiState.statusIsSuccess
                      ? "checkmark.circle.fill"
                      : "xmark.circle.fill")
                Text(viewModel.uiState.statusMessage).font(.subheadline)
            }
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10))
        }
    }

}

#Preview {
    RegisterTransactionView(viewModel: RegisterTransactionViewModel())
}
