import SwiftUI

struct FiatCurrencyView: View {

    @Environment(\.appTheme) private var theme
    @State private var selectedCurrency = UserDefaults.standard.preferredFiatCurrency

    var body: some View {
        List(FiatCurrency.allCases) { currency in
            buildCurrencyRow(currency)
        }
        .navigationTitle("Fiat Currency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildCurrencyRow(_ currency: FiatCurrency) -> some View {
        Button {
            selectedCurrency = currency
            UserDefaults.standard.preferredFiatCurrency = currency
        } label: {
            HStack(spacing: 12) {
                Text(currency.flag)
                    .font(.title2)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.rawValue)
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                    Text(currency.displayName)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.contentSecondary)
                }

                Spacer()

                if selectedCurrency == currency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.colors.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
