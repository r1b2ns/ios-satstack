import SwiftUI

// MARK: - WalletSettingsSheet

/// Sheet presented when the user taps the gear icon on a selected wallet.
///
/// Options:
/// - **Change Name** — dismisses the sheet and triggers the rename alert
/// - **Backup** — navigates to `SeedPhraseView` in read-only mode
/// - **Delete** — shows a confirmation alert; on confirmation removes the wallet
struct WalletSettingsSheet<ViewModel: WalletsViewModelProtocol>: View {

    let wallet: Wallet
    @ObservedObject var viewModel: ViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var showBackup = false
    @State private var showDeleteAlert = false
    @State private var sheetDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            buildOptionList()
                .navigationTitle(wallet.name)
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showBackup) {
                    buildBackupView()
                }
                .alert("Delete Wallet", isPresented: $showDeleteAlert) {
                    buildDeleteAlertActions()
                } message: {
                    Text("Are you sure you want to delete \"\(wallet.name)\"? This action cannot be undone.")
                }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: showBackup) { _, navigated in
            sheetDetent = navigated ? .large : .medium
        }
    }

    // MARK: - Option list

    private func buildOptionList() -> some View {
        List {
            Section {
                buildOptionRow(
                    icon: "pencil",
                    iconColor: .blue,
                    title: "Change Name"
                ) {
                    dismiss()
                    viewModel.showRenameAlert()
                }
                
                if wallet.mnemonicPhrase != nil {
                    buildOptionRow(
                        icon: "key.fill",
                        iconColor: .orange,
                        title: "Backup"
                    ) {
                        showBackup = true
                    }
                }
                
                buildOptionRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .purple,
                    title: "Force Full Scan"
                ) {
                    dismiss()
                    viewModel.forceFullScan()
                }
            }
            
            Section {
                buildOptionRow(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Delete",
                    titleColor: .red,
                    shouldShowChevron: false
                ) {
                    showDeleteAlert = true
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func buildOptionRow(
        icon: String,
        iconColor: Color,
        title: String,
        titleColor: Color = .primary,
        shouldShowChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 32, alignment: .center)
                Text(title)
                    .foregroundStyle(titleColor)
                Spacer()
                if shouldShowChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Backup view

    @ViewBuilder
    private func buildBackupView() -> some View {
        if let phrase = wallet.mnemonicPhrase {
            SeedPhraseView(
                words: phrase.components(separatedBy: " "),
                showConfirmButton: false,
                onConfirm: {}
            )
        }
    }

    // MARK: - Delete alert actions

    @ViewBuilder
    private func buildDeleteAlertActions() -> some View {
        Button("Yes", role: .destructive) {
            viewModel.deleteWallet(id: wallet.id)
            dismiss()
        }
        Button("Cancel", role: .cancel) {}
    }
}
