import SwiftUI

// MARK: - View

/// Displays the current Bitcoin price in the user's preferred fiat currency as a compact card widget.
struct FiatPriceWidget: View {

    /// Bitcoin price in the selected fiat currency.
    let price: Double

    /// The fiat currency used for formatting.
    let currency: FiatCurrency

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildHeader()
            buildPrice()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
    }

    // MARK: - Builders

    private func buildHeader() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.orange)
            Text("Bitcoin")
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
    }

    private func buildPrice() -> some View {
        Text(currency.formattedPrice(price))
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
