import WidgetKit
import SwiftUI

// MARK: - Timeline entry

/// A single snapshot of the Fear & Greed Index for the widget timeline.
struct GreedAndFearWidgetEntry: TimelineEntry {
    let date: Date
    let score: Int
    let label: String
}

// MARK: - Timeline provider

/// Fetches the Crypto Fear & Greed Index from Alternative.me and builds
/// a one-entry timeline that refreshes every hour.
struct GreedAndFearProvider: TimelineProvider {

    // MARK: - Placeholder

    func placeholder(in context: Context) -> GreedAndFearWidgetEntry {
        GreedAndFearWidgetEntry(date: .now, score: 50, label: "Neutral")
    }

    // MARK: - Snapshot

    func getSnapshot(in context: Context, completion: @escaping (GreedAndFearWidgetEntry) -> Void) {
        if let cached = cachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }

    // MARK: - Timeline

    func getTimeline(in context: Context, completion: @escaping (Timeline<GreedAndFearWidgetEntry>) -> Void) {
        Task {
            do {
                let entry = try await fetchFromAPI()
                let timeline = Timeline(
                    entries: [entry],
                    policy: .after(Date().addingTimeInterval(3600)) // refresh in 1 hour
                )
                completion(timeline)
            } catch {
                // On failure, use cached data and retry sooner
                let fallback = cachedEntry()
                    ?? GreedAndFearWidgetEntry(date: .now, score: 50, label: "Neutral")
                let timeline = Timeline(
                    entries: [fallback],
                    policy: .after(Date().addingTimeInterval(900)) // retry in 15 min
                )
                completion(timeline)
            }
        }
    }

    // MARK: - Network fetch

    /// Lightweight network call to `api.alternative.me/fng/` using plain URLSession.
    /// The widget extension cannot use the app's `NetworkManager` / `Requestable` layer.
    private func fetchFromAPI() async throws -> GreedAndFearWidgetEntry {
        let url = URL(string: "https://api.alternative.me/fng/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WidgetFearAndGreedResponse.self, from: data)

        guard let first = response.data.first, let score = Int(first.value) else {
            throw URLError(.cannotParseResponse)
        }

        // Persist for snapshot / fallback
        AppGroupStore.saveFearAndGreed(first)

        return GreedAndFearWidgetEntry(
            date: .now,
            score: score,
            label: first.valueClassification
        )
    }

    // MARK: - Cache

    private func cachedEntry() -> GreedAndFearWidgetEntry? {
        guard let cached = AppGroupStore.loadFearAndGreed(),
              let score = Int(cached.value) else { return nil }
        return GreedAndFearWidgetEntry(
            date: .now,
            score: score,
            label: cached.valueClassification
        )
    }
}

// MARK: - Lightweight response model (widget-only)

/// Minimal decodable wrapper used exclusively by the widget's URLSession call.
/// The full `FearAndGreedIndexResponse` lives in the main app target and
/// depends on `Requestable`, which is unavailable in the widget extension.
private struct WidgetFearAndGreedResponse: Decodable {
    let data: [FearAndGreedEntry]
}

// MARK: - Widget view

/// Replicates the in-app `GreedFearWidget` visual for the iOS home screen.
struct GreedAndFearWidgetView: View {

    let entry: GreedAndFearWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            buildHeader()
            if family != .systemSmall {
                buildColorBand()
            }
        }
        .padding(family == .systemSmall ? 4 : 8)
    }

    // MARK: - Header

    private func buildHeader() -> some View {
        HStack(alignment: .top) {
            buildTitleStack()
            Spacer()
            buildScoreLabel()
        }
    }

    private func buildTitleStack() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Greed & Fear")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(entry.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(scoreColor)
        }
    }

    private func buildScoreLabel() -> some View {
        Text("\(entry.score)")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(scoreColor)
    }

    // MARK: - Color band

    private func buildColorBand() -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                buildGradientCapsule()
                buildIndicator(in: proxy)
            }
        }
        .frame(height: 16)
    }

    private func buildGradientCapsule() -> some View {
        Capsule()
            .fill(LinearGradient(
                colors: [.red, .orange, .yellow, .green],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: 8)
            .padding(.vertical, 4)
    }

    private func buildIndicator(in proxy: GeometryProxy) -> some View {
        let clamped  = min(max(entry.score, 0), 100)
        let position = proxy.size.width * (Double(clamped) / 100.0)
        return Circle()
            .fill(.white)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .frame(width: 16, height: 16)
            .offset(x: position - 8)
    }

    // MARK: - Score color

    private var scoreColor: Color {
        switch entry.score {
        case 0..<25:  return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        default:      return .green
        }
    }
}

// MARK: - Widget definition

/// WidgetKit home screen widget displaying the Crypto Fear & Greed Index.
struct SatStackWidgetGreedAndFear: Widget {

    let kind = "SatStackWidgetGreedAndFear"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GreedAndFearProvider()) { entry in
            GreedAndFearWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Greed & Fear Index")
        .description("Crypto Fear and Greed Index from Alternative.me")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
