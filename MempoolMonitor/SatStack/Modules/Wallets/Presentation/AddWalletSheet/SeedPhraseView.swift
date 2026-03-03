import SwiftUI

// MARK: - SeedPhraseView

/// Displays a BIP-39 seed phrase in a numbered 3-column grid.
///
/// Reusable across any flow that needs to present or confirm a seed phrase backup.
/// - When `showConfirmButton` is `true` (default), shows the confirm button and hides the back button.
///   Use this in the wallet creation flow.
/// - When `showConfirmButton` is `false`, the back button is visible and no confirm action is required.
///   Use this in the backup / read-only view.
struct SeedPhraseView: View {

    let words: [String]
    var showConfirmButton: Bool = true
    let onConfirm: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                buildWarningBanner()
                buildWordGrid()
                if showConfirmButton {
                    buildConfirmButton()
                }
            }
            .padding(24)
        }
        .navigationTitle("Seed Phrase")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showConfirmButton)
    }

    // MARK: - Builders

    private func buildWarningBanner() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Write down these \(words.count) words in order and store them somewhere safe. They are the only way to recover your wallet.")
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
