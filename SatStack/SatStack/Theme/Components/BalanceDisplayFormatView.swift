import SwiftUI

/// A reusable view that displays a Bitcoin balance in the user's preferred format.
///
/// Automatically reacts to changes in `UserDefaults.preferredBalanceFormat`
/// and `UserDefaults.preferredFiatCurrency`. For the `.fiat` format, loads
/// the last persisted `PricesResponse` from SwiftData.
///
/// Since this view renders plain `Text`, all standard text modifiers
/// (`.font`, `.foregroundStyle`, `.fontWeight`, etc.) can be applied to it.
///
/// - Parameters:
///   - sats: The balance amount in satoshis.
struct BalanceDisplayFormatView: View {

    let sats: UInt64

    @State private var format: BalanceDisplayFormat = UserDefaults.standard.preferredBalanceFormat
    @State private var currency: FiatCurrency = UserDefaults.standard.preferredFiatCurrency
    @State private var prices: PricesResponse? = nil

    var body: some View {
        Text(formattedBalance)
            .task { await loadPrices() }
            .onReceive(
                NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            ) { _ in
                format   = UserDefaults.standard.preferredBalanceFormat
                currency = UserDefaults.standard.preferredFiatCurrency
            }
    }

    // MARK: - Formatting

    private var formattedBalance: String {
        switch format {
        case .bitcoin:
            let btc = Double(sats) / 100_000_000.0
            return String(format: "₿ %.8f", btc)

        case .sats:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: sats)) ?? "\(sats)") sats"

        case .bip177:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: sats)) ?? "\(sats)") ₿"

        case .fiat:
            guard let prices else { return "—" }
            let btc = Double(sats) / 100_000_000.0
            let fiatValue = btc * currency.price(from: prices)
            return currency.formattedPrice(fiatValue)
        }
    }

    // MARK: - Private

    private func loadPrices() async {
        prices = try? await SwiftDataStorable.shared.fetch(
            PricesResponse.self,
            id: "bitcoin_prices"
        )
    }
}
