import SwiftUI

/// Settings screen for selecting the user's preferred balance display format.
///
/// Shows all available `BalanceDisplayFormat` options with their display name,
/// an example string, and a checkmark next to the currently selected format.
/// Selecting a row immediately persists the choice to `UserDefaults`.
struct BalanceFormatView: View {

    @State private var selectedFormat = UserDefaults.standard.preferredBalanceFormat

    var body: some View {
        List(BalanceDisplayFormat.allCases) { format in
            buildFormatRow(format)
        }
        .navigationTitle("Balance Format")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildFormatRow(_ format: BalanceDisplayFormat) -> some View {
        Button {
            selectedFormat = format
            UserDefaults.standard.preferredBalanceFormat = format
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(format.example)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedFormat == format {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
