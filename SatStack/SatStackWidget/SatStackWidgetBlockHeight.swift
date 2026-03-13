import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct BlockHeightWidgetEntry: TimelineEntry {
    let date: Date
    let blockHeight: Int
}

// MARK: - Timeline provider

/// Fetches the current Bitcoin block height from Mempool.space.
struct BlockHeightProvider: TimelineProvider {

    func placeholder(in context: Context) -> BlockHeightWidgetEntry {
        BlockHeightWidgetEntry(date: .now, blockHeight: 840_000)
    }

    func getSnapshot(in context: Context, completion: @escaping (BlockHeightWidgetEntry) -> Void) {
        if let cached = cachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BlockHeightWidgetEntry>) -> Void) {
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
                    ?? BlockHeightWidgetEntry(date: .now, blockHeight: 840_000)
                let timeline = Timeline(
                    entries: [fallback],
                    policy: .after(Date().addingTimeInterval(300)) // retry in 5 min
                )
                completion(timeline)
            }
        }
    }

    // MARK: - Network fetch

    /// Fetches difficulty adjustment to derive the current block height
    /// (same approach as the in-app widget).
    private func fetchFromAPI() async throws -> BlockHeightWidgetEntry {
        let url = URL(string: "https://mempool.space/api/v1/difficulty-adjustment")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WidgetDifficultyResponse.self, from: data)

        let currentHeight = response.nextRetargetHeight - response.remainingBlocks

        // Also save halving info since we already have the data
        let halvingInterval = 210_000
        let nextHalvingHeight = ((currentHeight / halvingInterval) + 1) * halvingInterval
        let blocksUntil = nextHalvingHeight - currentHeight
        let avgBlockSeconds = response.timeAvg > 0
            ? Double(response.timeAvg) / 1_000
            : 600
        let estimatedDate = Date().addingTimeInterval(Double(blocksUntil) * avgBlockSeconds)
        let blocksIntoEpoch = currentHeight % halvingInterval
        let epochProgress = Double(blocksIntoEpoch) / Double(halvingInterval)

        let halving = SharedHalvingInfo(
            currentBlockHeight: currentHeight,
            nextHalvingHeight: nextHalvingHeight,
            blocksUntil: blocksUntil,
            estimatedDateTimestamp: estimatedDate.timeIntervalSince1970,
            epochProgress: epochProgress
        )
        AppGroupStore.saveHalving(halving)

        return BlockHeightWidgetEntry(date: .now, blockHeight: currentHeight)
    }

    // MARK: - Cache

    private func cachedEntry() -> BlockHeightWidgetEntry? {
        guard let cached = AppGroupStore.loadHalving() else { return nil }
        return BlockHeightWidgetEntry(date: .now, blockHeight: cached.currentBlockHeight)
    }
}

// MARK: - Lightweight response model (widget-only)

private struct WidgetDifficultyResponse: Decodable {
    let nextRetargetHeight: Int
    let remainingBlocks: Int
    let timeAvg: Int
}

// MARK: - Widget view

struct BlockHeightWidgetView: View {

    let entry: BlockHeightWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildIcon()
            buildTitle()
            buildBlockHeight()
        }
        .padding(4)
    }

    private func buildIcon() -> some View {
        Image(systemName: "cube.fill")
            .font(.largeTitle)
            .foregroundStyle(Color.blue)
    }

    private func buildTitle() -> some View {
        Text("Block Height")
            .font(.headline)
            .fontWeight(.semibold)
    }

    private func buildBlockHeight() -> some View {
        Text(formattedBlockHeight)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var formattedBlockHeight: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: entry.blockHeight)) ?? "\(entry.blockHeight)"
    }
}

// MARK: - Widget definition

struct SatStackWidgetBlockHeight: Widget {

    let kind = "SatStackWidgetBlockHeight"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BlockHeightProvider()) { entry in
            BlockHeightWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Block Height")
        .description("Current Bitcoin block height from Mempool.space")
        .supportedFamilies([.systemSmall])
    }
}
