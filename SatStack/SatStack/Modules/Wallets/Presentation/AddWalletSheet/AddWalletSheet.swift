import SwiftUI

// MARK: - AddWalletSheetView

/// Bottom sheet that lets the user choose how to add a wallet.
///
/// Navigation:
/// - Initial list  → **Create**, **Import**, **SatsCard** (Bitcoin section)
///                 → **Lightning Wallet** (Lightning section)
/// - Create        → `SeedPhraseView` — wallet saved after user confirms
/// - Import        → `ImportWalletView` — BIP-39 phrase entry
/// - SatsCard      → `SatsCardView` — NFC-based SatsCard flow
/// - Lightning     → `LightningWalletView` — Lightning wallet placeholder
struct AddWalletSheetView<ViewModel: WalletsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel

    @State private var showSeedPhrase = false
    @State private var showImport = false
    @State private var showSatsCard = false
    @State private var showLightning = false
    @State private var isCreating = false
    @State private var creationResult: CreationResult?
    @State private var sheetDetent: PresentationDetent = .height(380)

    /// True whenever a child screen is pushed — used to expand the sheet.
    private var isNavigated: Bool {
        showSeedPhrase || showImport || showSatsCard || showLightning
    }

    var body: some View {
        NavigationStack {
            buildOptionList()
                .navigationTitle("Choose an option")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showSeedPhrase) {
                    if let result = creationResult {
                        SeedPhraseView(words: result.words) {
                            viewModel.addWallet(result.wallet)
                        }
                    }
                }
                .navigationDestination(isPresented: $showImport) {
                    ImportWalletView(viewModel: viewModel)
                }
                .navigationDestination(isPresented: $showSatsCard) {
                    SatsCardView()
                }
                .navigationDestination(isPresented: $showLightning) {
                    LightningWalletView()
                }
                .onChange(of: isNavigated) { _, navigated in
                    sheetDetent = navigated ? .large : .height(380)
                }
        }
        .presentationDetents([.height(380), .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Option list

    private func buildOptionList() -> some View {
        List {
            Section {
                ForEach(BitcoinOption.allCases, id: \.self) { option in
                    buildBitcoinRow(option)
                }
            }

            Section("Lightning") {
                buildLightningRow()
            }
        }
        .listStyle(.insetGrouped)
    }

    private func buildBitcoinRow(_ option: BitcoinOption) -> some View {
        Button {
            handleSelection(option)
        } label: {
            HStack(spacing: 14) {
                buildLeadingIcon(systemName: option.icon, color: option.iconColor)
                Text(option.title)
                    .foregroundStyle(.primary)
                Spacer()
                buildTrailingIndicator(isLoading: isCreating && option == .create)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }

    private func buildLightningRow() -> some View {
        Button {
            showLightning = true
        } label: {
            HStack(spacing: 14) {
                buildLeadingIcon(systemName: "bolt.fill", color: .yellow)
                Text("Lightning Wallet")
                    .foregroundStyle(.primary)
                Spacer()
                buildTrailingIndicator(isLoading: false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func buildLeadingIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 32, alignment: .center)
    }

    private func buildTrailingIndicator(isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func handleSelection(_ option: BitcoinOption) {
        switch option {
        case .create:   Task { await createWallet() }
        case .import:   showImport = true
        case .satsCard: showSatsCard = true
        }
    }

    @MainActor
    private func createWallet() async {
        isCreating = true
        do {
            let result = try await viewModel.createWallet()
            if case .seedPhrase(let words) = result.backup.kind {
                creationResult = CreationResult(words: words, wallet: result.wallet)
                showSeedPhrase = true
            }
        } catch {
            Log.print.error("Wallet creation failed: \(error.localizedDescription)")
        }
        isCreating = false
    }
}

// MARK: - BitcoinOption

private enum BitcoinOption: CaseIterable {
    case create
    case `import`
    case satsCard

    var title: String {
        switch self {
        case .create:   return "New Wallet"
        case .import:   return "Import"
        case .satsCard: return "SatsCard"
        }
    }

    var icon: String {
        switch self {
        case .create:   return "plus.circle.fill"
        case .import:   return "arrow.down.circle.fill"
        case .satsCard: return "creditcard.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .create:   return .orange
        case .import:   return .blue
        case .satsCard: return .purple
        }
    }
}

// MARK: - CreationResult

private struct CreationResult {
    let words: [String]
    let wallet: Wallet
}
