import SwiftUI

/// Settings screen for selecting the user's preferred wallet sync backend.
///
/// Shows all available `SyncPreference` options with their display name,
/// a short description, and a checkmark next to the currently selected option.
/// Selecting a row immediately persists the choice to `UserDefaults`.
struct SyncPreferenceView: View {

    @State private var selectedPreference = UserDefaults.standard.preferredSyncPreference

    var body: some View {
        List(SyncPreference.allCases) { preference in
            buildPreferenceRow(preference)
        }
        .navigationTitle("Sync Preferred")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPreferenceRow(_ preference: SyncPreference) -> some View {
        Button {
            selectedPreference = preference
            UserDefaults.standard.preferredSyncPreference = preference
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preference.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(preference.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedPreference == preference {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
