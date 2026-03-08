import SwiftUI

// MARK: - SatsCardView

/// Placeholder for the SatsCard NFC import flow.
struct SatsCardView: View {

    @Environment(\.openURL) private var openURL

    private let satsCardURL = URL(string: "https://satscard.com/")!

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            buildIcon()
            buildLabels()
            buildBuyLink()

            Spacer()
        }
        .padding(.horizontal, 20)
        .navigationTitle("SatsCard")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Icon

    private func buildIcon() -> some View {
        Image(systemName: "creditcard.fill")
            .font(.system(size: 56))
            .foregroundStyle(.purple)
    }

    // MARK: - Labels

    private func buildLabels() -> some View {
        VStack(spacing: 8) {
            Text("Coming Soon")
                .font(.title2)
                .fontWeight(.bold)

            Text("NFC-based SatsCard import will be available in a future update.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Buy link

    private func buildBuyLink() -> some View {
        Button {
            openURL(satsCardURL)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cart.fill")
                Text("Buy a SatsCard")
            }
            .font(.subheadline)
            .fontWeight(.medium)
        }
    }
}
