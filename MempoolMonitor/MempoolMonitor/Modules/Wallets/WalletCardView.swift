import SwiftUI

/// Apple Wallet-style card that represents a single wallet entry.
///
/// Displays the wallet theme icon and type badge at the top,
/// and the wallet name with BTC balance at the bottom.
struct WalletCardView: View {

    let wallet: Wallet

    var body: some View {
        ZStack(alignment: .topLeading) {
            buildBackground()
            buildContent()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    // MARK: - Builders

    private func buildBackground() -> some View {
        wallet.theme.gradient
    }

    private func buildContent() -> some View {
        VStack(alignment: .leading) {
            buildTopRow()
            Spacer()
            buildBalanceSection()
        }
        .padding(24)
    }

    private func buildTopRow() -> some View {
        HStack(alignment: .top) {
            Image(systemName: wallet.theme.systemImage)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(wallet.theme.displayName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)
        }
    }

    private func buildBalanceSection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wallet.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
            Text("₿ \(formattedBalance)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private var formattedBalance: String {
        String(format: "%.8f", wallet.balanceBTC)
    }
}
