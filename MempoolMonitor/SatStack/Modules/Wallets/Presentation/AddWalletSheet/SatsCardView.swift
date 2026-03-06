import SwiftUI

// MARK: - SatsCardView

/// Placeholder for the SatsCard NFC import flow.
struct SatsCardView: View {

    var body: some View {
        ContentUnavailableView(
            "SatsCard",
            systemImage: "creditcard.fill",
            description: Text("NFC-based SatsCard import will be available in a future update.")
        )
        .navigationTitle("SatsCard")
        .navigationBarTitleDisplayMode(.inline)
    }
}
