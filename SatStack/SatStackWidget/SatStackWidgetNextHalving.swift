import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct NextHalvingWidgetEntry: TimelineEntry {
    let date: Date
    let blocksUntil: Int
    let nextHalvingHeight: Int
    let estimatedDate: Date
    let epochProgress: Double
}

// MARK: - Timeline provider

/// Fetches difficulty adjustment data from Mempool.space to compute
/// next halving info.
struct NextHalvingProvider: TimelineProvider {

    func placeholder(in context: Context) -> NextHalvingWidgetEntry {
        NextHalvingWidgetEntry(
            date: .now,
            blocksUntil: 100_000,
            nextHalvingHeight: 1_050_000,
            estimatedDate: Date().addingTimeInterval(86_400 * 365),
            epochProgress: 0.52
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextHalvingWidgetEntry) -> Void) {
        if let cached = cachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextHalvingWidgetEntry>) -> Void) {
        Task {
            do {
                let entry = try await fetchFromAPI()
                let timeline = Timeline(
                    entries: [entry],
                    policy: .after(Date().addingTimeInterval(3600)) // refresh in 1 hour
                )
                completion(timeline)
            } catch {
                let fallback = cachedEntry()
                    ?? NextHalvingWidgetEntry(
                        date: .now,
                        blocksUntil: 100_000,
                        nextHalvingHeight: 1_050_000,
                        estimatedDate: Date().addingTimeInterval(86_400 * 365),
                        epochProgress: 0.52
                    )
                let timeline = Timeline(
                    entries: [fallback],
                    policy: .after(Date().addingTimeInterval(900)) // retry in 15 min
                )
                completion(timeline)
            }
        }
    }

    // MARK: - Network fetch

    private func fetchFromAPI() async throws -> NextHalvingWidgetEntry {
        let url = URL(string: "https://mempool.space/api/v1/difficulty-adjustment")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WidgetDifficultyResponse.self, from: data)

        let halvingInterval = 210_000
        let currentHeight = response.nextRetargetHeight - response.remainingBlocks
        let nextHalvingHeight = ((currentHeight / halvingInterval) + 1) * halvingInterval
        let blocksUntil = nextHalvingHeight - currentHeight

        let avgBlockSeconds = response.timeAvg > 0
            ? Double(response.timeAvg) / 1_000
            : 600
        let estimatedDate = Date().addingTimeInterval(Double(blocksUntil) * avgBlockSeconds)

        let blocksIntoEpoch = currentHeight % halvingInterval
        let epochProgress = Double(blocksIntoEpoch) / Double(halvingInterval)

        let shared = SharedHalvingInfo(
            currentBlockHeight: currentHeight,
            nextHalvingHeight: nextHalvingHeight,
            blocksUntil: blocksUntil,
            estimatedDateTimestamp: estimatedDate.timeIntervalSince1970,
            epochProgress: epochProgress
        )
        AppGroupStore.saveHalving(shared)

        return NextHalvingWidgetEntry(
            date: .now,
            blocksUntil: blocksUntil,
            nextHalvingHeight: nextHalvingHeight,
            estimatedDate: estimatedDate,
            epochProgress: epochProgress
        )
    }

    // MARK: - Cache

    private func cachedEntry() -> NextHalvingWidgetEntry? {
        guard let cached = AppGroupStore.loadHalving() else { return nil }
        return NextHalvingWidgetEntry(
            date: .now,
            blocksUntil: cached.blocksUntil,
            nextHalvingHeight: cached.nextHalvingHeight,
            estimatedDate: Date(timeIntervalSince1970: cached.estimatedDateTimestamp),
            epochProgress: cached.epochProgress
        )
    }
}

// MARK: - Lightweight response model (widget-only)

private struct WidgetDifficultyResponse: Decodable {
    let nextRetargetHeight: Int
    let remainingBlocks: Int
    let timeAvg: Int
}

// MARK: - Widget view

struct NextHalvingWidgetView: View {

    let entry: NextHalvingWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildIcon()
            buildTitle()
            buildSubtitle()
            buildProgressBar()
        }
        .padding(4)
    }

    private func buildIcon() -> some View {
        Image(systemName: "calendar.badge.clock")
            .font(.largeTitle)
            .foregroundStyle(Color.purple)
    }

    private func buildTitle() -> some View {
        Text("Next Halving")
            .font(.headline)
            .fontWeight(.semibold)
    }

    private func buildSubtitle() -> some View {
        Text(daysLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func buildProgressBar() -> some View {
        ProgressView(value: entry.epochProgress)
            .tint(.purple)
    }

    private var daysLabel: String {
        let seconds = entry.estimatedDate.timeIntervalSinceNow
        guard seconds > 0 else { return "Imminent!" }
        let days = Int(seconds / 86_400)
        return days > 0 ? "~\(days) days" : "< 1 day"
    }
}

// MARK: - Widget definition

struct SatStackWidgetNextHalving: Widget {

    let kind = "SatStackWidgetNextHalving"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextHalvingProvider()) { entry in
            NextHalvingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Halving")
        .description("Bitcoin halving countdown with epoch progress from Mempool.space")
        .supportedFamilies([.systemSmall])
    }
}
