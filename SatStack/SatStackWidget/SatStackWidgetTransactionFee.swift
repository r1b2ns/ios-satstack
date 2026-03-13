import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct TransactionFeeWidgetEntry: TimelineEntry {
    let date: Date
    let fastestFee: Int
    let hourFee: Int
    let economyFee: Int
}

// MARK: - Timeline provider

/// Fetches recommended Bitcoin transaction fee rates from Mempool.space.
struct TransactionFeeProvider: TimelineProvider {

    func placeholder(in context: Context) -> TransactionFeeWidgetEntry {
        TransactionFeeWidgetEntry(date: .now, fastestFee: 10, hourFee: 5, economyFee: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (TransactionFeeWidgetEntry) -> Void) {
        if let cached = cachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TransactionFeeWidgetEntry>) -> Void) {
        Task {
            do {
                let entry = try await fetchFromAPI()
                let timeline = Timeline(
                    entries: [entry],
                    policy: .after(Date().addingTimeInterval(600)) // refresh in 10 min
                )
                completion(timeline)
            } catch {
                let fallback = cachedEntry()
                    ?? TransactionFeeWidgetEntry(date: .now, fastestFee: 10, hourFee: 5, economyFee: 2)
                let timeline = Timeline(
                    entries: [fallback],
                    policy: .after(Date().addingTimeInterval(300)) // retry in 5 min
                )
                completion(timeline)
            }
        }
    }

    // MARK: - Network fetch

    private func fetchFromAPI() async throws -> TransactionFeeWidgetEntry {
        let url = URL(string: "https://mempool.space/api/v1/fees/recommended")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WidgetFeesResponse.self, from: data)

        let shared = SharedRecommendedFees(
            fastestFee: response.fastestFee,
            hourFee: response.hourFee,
            economyFee: response.economyFee
        )
        AppGroupStore.saveFees(shared)

        return TransactionFeeWidgetEntry(
            date: .now,
            fastestFee: response.fastestFee,
            hourFee: response.hourFee,
            economyFee: response.economyFee
        )
    }

    // MARK: - Cache

    private func cachedEntry() -> TransactionFeeWidgetEntry? {
        guard let cached = AppGroupStore.loadFees() else { return nil }
        return TransactionFeeWidgetEntry(
            date: .now,
            fastestFee: cached.fastestFee,
            hourFee: cached.hourFee,
            economyFee: cached.economyFee
        )
    }
}

// MARK: - Lightweight response model (widget-only)

private struct WidgetFeesResponse: Decodable {
    let fastestFee: Int
    let halfHourFee: Int
    let hourFee: Int
    let economyFee: Int
    let minimumFee: Int
}

// MARK: - Widget view

struct TransactionFeeWidgetView: View {

    let entry: TransactionFeeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildHeader()
            buildFeeRows()
        }
        .padding(4)
    }

    private func buildHeader() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.headline)
                .foregroundStyle(Color.green)
            Text("Fees")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    private func buildFeeRows() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            buildFeeRow(label: "Fast", value: entry.fastestFee, color: .red)
            buildFeeRow(label: "Hour", value: entry.hourFee, color: .orange)
            buildFeeRow(label: "Economy", value: entry.economyFee, color: .green)
        }
    }

    private func buildFeeRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value) sat/vB")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Widget definition

struct SatStackWidgetTransactionFee: Widget {

    let kind = "SatStackWidgetTransactionFee"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TransactionFeeProvider()) { entry in
            TransactionFeeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Transaction Fees")
        .description("Recommended Bitcoin transaction fee rates from Mempool.space")
        .supportedFamilies([.systemSmall])
    }
}
