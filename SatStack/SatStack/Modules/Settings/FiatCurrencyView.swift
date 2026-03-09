import SwiftUI

struct FiatCurrencyView: View {

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
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(currency.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedCurrency == currency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
