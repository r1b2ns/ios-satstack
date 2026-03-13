import SwiftUI

/// Settings screen for selecting the wallet sync backend.
///
/// Shows all available `SyncMode` options with their display name,
/// a short description, and a checkmark next to the currently selected mode.
/// Selecting a row immediately persists the choice to `UserDefaults`.
struct SyncModeView: View {

    @State private var selectedMode = UserDefaults.standard.preferredSyncMode

    var body: some View {
        List(SyncMode.allCases) { mode in
            buildModeRow(mode)
        }
        .navigationTitle("Sync Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildModeRow(_ mode: SyncMode) -> some View {
        Button {
            guard selectedMode != mode else { return }
            selectedMode = mode
            UserDefaults.standard.preferredSyncMode = mode

            Log.print.info("[Settings] SyncMode changed to: \(mode.displayName)")
            NotificationCenter.default.post(name: .syncModeDidChange, object: nil)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedMode == mode {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
