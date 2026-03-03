import BitcoinDevKit
import SwiftUI

// MARK: - AddWalletSheet

/// Bottom sheet that orchestrates the "New Wallet" flow.
///
/// Navigation:
/// - Initial view  → two buttons: **Create** and **Import**
/// - Create        → seed phrase display; wallet is saved after the user confirms
/// - Import        → text field for a BIP-39 phrase + **Import** button
struct AddWalletSheetView<ViewModel: WalletsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel

    @State private var showSeedPhrase = false
    @State private var showImport = false
    @State private var isCreating = false
    @State private var creationResult: CreationResult?

    var body: some View {
        NavigationStack {
            buildInitialView()
                .navigationTitle("New Wallet")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showSeedPhrase) {
                    if let result = creationResult {
                        buildSeedPhraseView(words: result.words, wallet: result.wallet)
                    }
                }
                .navigationDestination(isPresented: $showImport) {
                    buildImportView()
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Initial view

    private func buildInitialView() -> some View {
        VStack(spacing: 16) {
            Spacer()
            buildCreateButton()
            buildImportButton()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func buildCreateButton() -> some View {
        Button {
            Task { await createWallet() }
        } label: {
            HStack(spacing: 10) {
                if isCreating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Create")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isCreating)
    }

    private func buildImportButton() -> some View {
        Button {
            showImport = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Import")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Seed phrase view

    private func buildSeedPhraseView(words: [String], wallet: Wallet) -> some View {
        SeedPhraseView(words: words) {
            viewModel.addWallet(wallet)
        }
    }

    // MARK: - Import view

    private func buildImportView() -> some View {
        ImportWalletView(
            walletCount: viewModel.uiState.wallets.count,
            onImport: { wallet in viewModel.addWallet(wallet) }
        )
    }

    // MARK: - Create wallet

    @MainActor
    private func createWallet() async {
        isCreating = true
        let mnemonic = Mnemonic(wordCount: .words12)
        let phrase = mnemonic.description
        let words = phrase.components(separatedBy: " ")
        let wallet = Wallet(
            id: UUID(),
            name: "My Wallet \(viewModel.uiState.wallets.count + 1)",
            theme: .bitcoin,
            balanceBTC: 0.0,
            mnemonicPhrase: phrase
        )
        creationResult = CreationResult(words: words, wallet: wallet)
        isCreating = false
        showSeedPhrase = true
    }
}

// MARK: - CreationResult

private struct CreationResult {
    let words: [String]
    let wallet: Wallet
}

// MARK: - SeedPhraseView

/// Displays the 12-word seed phrase in a numbered grid.
/// The wallet is only saved after the user taps "I've saved my seed phrase".
private struct SeedPhraseView: View {

    let words: [String]
    let onConfirm: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                buildWarningBanner()
                buildWordGrid()
                buildConfirmButton()
            }
            .padding(24)
        }
        .navigationTitle("Seed Phrase")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func buildWarningBanner() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Write down these 12 words in order and store them somewhere safe. They are the only way to recover your wallet.")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func buildWordGrid() -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                buildWordChip(index: index + 1, word: word)
            }
        }
    }

    private func buildWordChip(index: Int, word: String) -> some View {
        HStack(spacing: 6) {
            Text("\(index).")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            Text(word)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func buildConfirmButton() -> some View {
        Button(action: onConfirm) {
            Text("I've saved my seed phrase")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 8)
    }
}

// MARK: - ImportWalletView

/// Screen with a `TextEditor` where the user pastes or types a BIP-39 seed phrase.
/// The phrase is validated with BDK before the wallet is created.
private struct ImportWalletView: View {

    let walletCount: Int
    let onImport: (Wallet) -> Void

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

    private func buildInstructions() -> some View {
        Text("Enter your 12 or 24-word seed phrase, with each word separated by a space.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func buildPhraseEditor() -> some View {
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
            .background(isImportEnabled ? Color.orange : Color.gray.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isImportEnabled)
    }

    @MainActor
    private func importWallet() async {
        isImporting = true
        errorMessage = nil

        do {
            _ = try Mnemonic.fromString(mnemonic: trimmedPhrase)
            let wallet = Wallet(
                id: UUID(),
                name: "Imported Wallet \(walletCount + 1)",
                theme: .bitcoin,
                balanceBTC: 0.0,
                mnemonicPhrase: trimmedPhrase
            )
            onImport(wallet)
        } catch {
            errorMessage = "Invalid seed phrase. Please check all words and try again."
            Log.print.warning("Wallet import failed: \(error.localizedDescription)")
        }

        isImporting = false
    }
}
