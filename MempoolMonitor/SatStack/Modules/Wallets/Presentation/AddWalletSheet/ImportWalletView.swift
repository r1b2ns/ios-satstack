import SwiftUI

// MARK: - ImportWalletView

/// Screen where the user enters a BIP-39 seed phrase to import a wallet.
///
/// Delegates validation and wallet creation to the injected `ViewModel`,
/// which calls `BDKWalletService.importWallet(from:)` internally.
struct ImportWalletView<ViewModel: WalletsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel

    @State private var phrase: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var trimmedPhrase: String { phrase.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isImportEnabled: Bool { !trimmedPhrase.isEmpty && !isImporting }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                buildInstructions()
                buildPhraseEditor()
                if let error = errorMessage { buildErrorLabel(error) }
                buildImportButton()
            }
            .padding(24)
        }
        .navigationTitle("Import Wallet")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Builders

    private func buildInstructions() -> some View {
        Text("Enter your 12 or 24-word seed phrase, with each word separated by a space.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func buildPhraseEditor() -> some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $phrase)
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

            buildPasteButton()
        }
    }

    private func buildPasteButton() -> some View {
        Button {
            guard let clipboard = UIPasteboard.general.string, !clipboard.isEmpty else { return }
            phrase = clipboard
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.callout)
                .foregroundStyle(.blue)
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(8)
        .opacity(phrase.isEmpty ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: phrase.isEmpty)
    }

    private func buildErrorLabel(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
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
            try await viewModel.importWallet(phrase: trimmedPhrase)
        } catch {
            errorMessage = "Invalid seed phrase. Please check all words and try again."
            Log.print.warning("Wallet import failed: \(error.localizedDescription)")
        }

        isImporting = false
    }
}
