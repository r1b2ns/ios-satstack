import SwiftUI

/// Apple-style welcome screen displayed on first launch.
///
/// Follows the Human Interface Guidelines pattern seen in first-party
/// apps: a prominent title, a list of feature highlights with coloured
/// icons, and a full-width "Continue" button at the bottom.
struct WelcomeView: View {

    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL

    /// Called when the user taps "Continue".
    let onContinue: () -> Void

    private let bdkURL = URL(string: "https://github.com/bitcoindevkit")!

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            buildTitle()

            Spacer()
                .frame(height: 40)

            buildFeatures()

            Spacer()

            buildDisclaimer()
            Spacer().frame(height: 12)
            buildContinueButton()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Title

    private func buildTitle() -> some View {
        VStack(spacing: 8) {
            Text("Welcome to")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("SatStack")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(theme.colors.accent)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Features

    private func buildFeatures() -> some View {
        VStack(spacing: 28) {
            buildFeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: theme.colors.widgetFees,
                title: "Real-Time Dashboard",
                description: "Live Bitcoin price, network fees, block height and market sentiment at a glance."
            )

            buildFeatureRow(
                icon: "key.fill",
                iconColor: theme.colors.accent,
                title: "Self-Custody Wallets",
                description: "Create or import wallets. Your keys, your coins — always under your control."
            )

            buildFeatureRow(
                icon: "bell.badge.fill",
                iconColor: theme.colors.widgetHalving,
                title: "Transaction Monitoring",
                description: "Watch transactions and get real-time updates with Live Activities on your Lock Screen."
            )

            buildFeatureRow(
                icon: "lock.open.fill",
                iconColor: theme.colors.warning,
                title: "Open Source",
                description: "Fully transparent codebase you can audit, contribute to, and trust, no hidden tracking."
            )
        }
    }

    private func buildFeatureRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.typography.body)
                    .fontWeight(.semibold)

                Text(description)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colors.contentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Disclaimer

    private func buildDisclaimer() -> some View {
        VStack(spacing: 4) {
            Text("Independent project powered by")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.contentSecondary)

            Button {
                openURL(bdkURL)
            } label: {
                Text("Bitcoin Dev Kit")
                    .font(theme.typography.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Continue button

    private func buildContinueButton() -> some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.accentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.shape.cornerRadiusButton))
        }
    }
}
