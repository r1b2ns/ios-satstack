import SwiftUI

// MARK: - AddWalletSheetView

/// Bottom sheet that lets the user choose how to add a wallet.
///
/// Navigation:
/// - Initial list  → **Create**, **Import**, **SatsCard**
/// - Create        → `SeedPhraseView` — wallet saved after user confirms
/// - Import        → `ImportWalletView` — BIP-39 phrase entry
/// - SatsCard      → `SatsCardView` — NFC-based SatsCard flow
struct AddWalletSheetView<ViewModel: WalletsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel

    @State private var showSeedPhrase = false
    @State private var showImport = false
    @State private var showSatsCard = false
    @State private var isCreating = false
    @State private var creationResult: CreationResult?
    @State private var sheetDetent: PresentationDetent = .height(280)

    /// True whenever a child screen is pushed — used to expand the sheet.
    private var isNavigated: Bool { showSeedPhrase || showImport || showSatsCard }

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
                .onChange(of: isNavigated) { _, navigated in
                    sheetDetent = navigated ? .large : .height(280)
                }
        }
        .presentationDetents([.height(280), .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Option list

    private func buildOptionList() -> some View {
        List {
            ForEach(WalletOption.allCases, id: \.self) { option in
                buildOptionRow(option)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func buildOptionRow(_ option: WalletOption) -> some View {
        Button {
            handleSelection(option)
        } label: {
            HStack(spacing: 14) {
                buildLeadingIcon(option)
                Text(option.title)
                    .foregroundStyle(.primary)
                Spacer()
                buildTrailingIndicator(option)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }

    private func buildLeadingIcon(_ option: WalletOption) -> some View {
        Image(systemName: option.icon)
            .font(.title3)
            .foregroundStyle(option.iconColor)
            .frame(width: 32, alignment: .center)
    }

    private func buildTrailingIndicator(_ option: WalletOption) -> some View {
        Group {
            if isCreating && option == .create {
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

    private func handleSelection(_ option: WalletOption) {
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

// MARK: - WalletOption

private enum WalletOption: CaseIterable {
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
