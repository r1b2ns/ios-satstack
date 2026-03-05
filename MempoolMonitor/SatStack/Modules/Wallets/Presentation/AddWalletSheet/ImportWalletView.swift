import SwiftUI

// MARK: - ImportWalletView

/// Screen where the user enters a seed phrase, xpub, or Bitcoin address to import a wallet.
///
/// Delegates validation and wallet creation to the injected `ViewModel`,
/// which auto-detects the input type and calls `BDKWalletService.importWallet(from:)`.
struct ImportWalletView<ViewModel: WalletsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel

    @State private var input: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var clipboardHasContent = false

    private var trimmedInput: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isImportEnabled: Bool { !trimmedInput.isEmpty && !isImporting }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                buildInstructions()
                buildInputEditor()
                if let error = errorMessage { buildErrorLabel(error) }
                buildPasteButton()
                buildImportButton()
            }
            .padding(24)
        }
        .navigationTitle("Import Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { checkClipboard() }
    }

    // MARK: - Builders

    private func buildInstructions() -> some View {
        Text("Enter a 12 or 24-word seed phrase, an extended public key (xpub/ypub/zpub/tpub/upub/vpub), or a Bitcoin address.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func buildInputEditor() -> some View {
        TextEditor(text: $input)
            .frame(minHeight: 140)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(errorMessage != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    private func buildErrorLabel(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func buildPasteButton() -> some View {
        Button {
            guard let clipboard = UIPasteboard.general.string, !clipboard.isEmpty else { return }
            input = clipboard
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                Text("Paste")
            }
        }
        .buttonStyle(.appSecondary)
        .disabled(!clipboardHasContent || !input.isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildImportButton() -> some View {
        Button {
            Task { await importWallet() }
        } label: {
            HStack(spacing: 8) {
                if isImporting {
                    ProgressView().tint(.white)
                } else {
                    Text("Import")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isImportEnabled ? Color.blue : Color.gray.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isImportEnabled)
    }

    // MARK: - Import

    @MainActor
    private func importWallet() async {
        isImporting = true
        errorMessage = nil

        do {
            try await viewModel.importWallet(input: trimmedInput)
        } catch {
            errorMessage = error.localizedDescription
            Log.print.warning("Wallet import failed: \(error.localizedDescription)")
        }

        isImporting = false
    }

    // MARK: - Clipboard

    private func checkClipboard() {
        clipboardHasContent = UIPasteboard.general.hasStrings
    }
}
