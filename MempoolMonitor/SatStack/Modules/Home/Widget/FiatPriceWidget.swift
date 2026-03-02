import SwiftUI

// MARK: - View

/// Displays the current Bitcoin price in US dollars as a compact card widget.
struct FiatPriceWidget: View {

    /// Bitcoin price in US dollars.
    let usdPrice: Double

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
        Text(formattedPrice)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    // MARK: - Formatting

    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: usdPrice)) ?? "$\(Int(usdPrice))"
    }
}
