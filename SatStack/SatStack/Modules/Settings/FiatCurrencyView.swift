import SwiftUI

struct FiatCurrencyView: View {

    @State private var selectedCurrency = UserDefaults.standard.preferredFiatCurrency
    @State private var prices: PricesResponse? = nil

    var body: some View {
        List(FiatCurrency.allCases) { currency in
            buildCurrencyRow(currency)
        }
        .navigationTitle("Fiat Currency")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            prices = try? await SwiftDataStorable.shared.fetch(
                PricesResponse.self,
                id: "bitcoin_prices"
            )
        }
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

                buildTrailing(for: currency)
            }
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func buildTrailing(for currency: FiatCurrency) -> some View {
        HStack(spacing: 12) {
            if let prices {
                Text(currency.formattedPrice(currency.price(from: prices)))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            if selectedCurrency == currency {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
    }
}
