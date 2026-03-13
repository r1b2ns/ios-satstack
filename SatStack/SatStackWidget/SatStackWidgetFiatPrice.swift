import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct FiatPriceWidgetEntry: TimelineEntry {
    let date: Date
    let formattedPrice: String
    let currencyCode: String
}

// MARK: - Timeline provider

/// Fetches Bitcoin prices from Mempool.space and displays in the user's
/// preferred fiat currency.
struct FiatPriceProvider: TimelineProvider {

    func placeholder(in context: Context) -> FiatPriceWidgetEntry {
        FiatPriceWidgetEntry(date: .now, formattedPrice: "$98,000", currencyCode: "USD")
    }

    func getSnapshot(in context: Context, completion: @escaping (FiatPriceWidgetEntry) -> Void) {
        if let cached = cachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FiatPriceWidgetEntry>) -> Void) {
        Task {
            do {
                let entry = try await fetchFromAPI()
                let timeline = Timeline(
                    entries: [entry],
                    policy: .after(Date().addingTimeInterval(900)) // refresh in 15 min
                )
                completion(timeline)
            } catch {
                let fallback = cachedEntry()
                    ?? FiatPriceWidgetEntry(date: .now, formattedPrice: "—", currencyCode: "USD")
                let timeline = Timeline(
                    entries: [fallback],
                    policy: .after(Date().addingTimeInterval(300)) // retry in 5 min
                )
                completion(timeline)
            }
        }
    }

    // MARK: - Network fetch

    private func fetchFromAPI() async throws -> FiatPriceWidgetEntry {
        let url = URL(string: "https://mempool.space/api/v1/prices")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WidgetPricesResponse.self, from: data)

        // Read the user's preferred currency from App Group UserDefaults
        let currencyCode = AppGroupStore.defaults.string(forKey: "preferredFiatCurrency") ?? "USD"

        let shared = SharedPrices(
            usd: response.usd,
            eur: response.eur,
            gbp: response.gbp,
            cad: response.cad,
            chf: response.chf,
            aud: response.aud,
            jpy: response.jpy,
            preferredCurrencyCode: currencyCode
        )
        AppGroupStore.savePrices(shared)

        return FiatPriceWidgetEntry(
            date: .now,
            formattedPrice: shared.formattedPreferredPrice,
            currencyCode: currencyCode
        )
    }

    // MARK: - Cache

    private func cachedEntry() -> FiatPriceWidgetEntry? {
        guard let cached = AppGroupStore.loadPrices() else { return nil }
        return FiatPriceWidgetEntry(
            date: .now,
            formattedPrice: cached.formattedPreferredPrice,
            currencyCode: cached.preferredCurrencyCode
        )
    }
}

// MARK: - Lightweight response model (widget-only)

private struct WidgetPricesResponse: Decodable {
    let usd: Double
    let eur: Double
    let gbp: Double
    let cad: Double
    let chf: Double
    let aud: Double
    let jpy: Double

    enum CodingKeys: String, CodingKey {
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case cad = "CAD"
        case chf = "CHF"
        case aud = "AUD"
        case jpy = "JPY"
    }
}

// MARK: - Widget view

struct FiatPriceWidgetView: View {

    let entry: FiatPriceWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildHeader()
            buildPrice()
        }
        .padding(4)
    }

    private func buildHeader() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.orange)
            Text("Bitcoin")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    private func buildPrice() -> some View {
        Text(entry.formattedPrice)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Widget definition

struct SatStackWidgetFiatPrice: Widget {

    let kind = "SatStackWidgetFiatPrice"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FiatPriceProvider()) { entry in
            FiatPriceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Bitcoin price in your preferred fiat currency from Mempool.space")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
