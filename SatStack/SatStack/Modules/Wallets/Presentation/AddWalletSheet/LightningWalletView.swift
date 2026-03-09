import SwiftUI

// MARK: - LightningWalletView

/// Placeholder for the Lightning Wallet integration flow.
struct LightningWalletView: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            buildIcon()
            buildLabels()

            Spacer()
        }
        .padding(.horizontal, 20)
        .navigationTitle("Lightning Wallet")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Icon

    private func buildIcon() -> some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 56))
            .foregroundStyle(.yellow)
    }

    // MARK: - Labels

    private func buildLabels() -> some View {
        VStack(spacing: 8) {
            Text("Coming Soon")
                .font(.title2)
                .fontWeight(.bold)

            Text("Lightning wallet integration will be available in a future update.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
