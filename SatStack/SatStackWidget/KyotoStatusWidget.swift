import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct KyotoStatusEntry: TimelineEntry {
    let date: Date
    let status: KyotoNodeConnectionStatus
}

// MARK: - Timeline Provider

struct KyotoStatusProvider: TimelineProvider {

    private var appGroupId: String {
        Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String ?? ""
    }

    func placeholder(in context: Context) -> KyotoStatusEntry {
        KyotoStatusEntry(date: Date(), status: .disconnected)
    }

    func getSnapshot(in context: Context, completion: @escaping (KyotoStatusEntry) -> Void) {
        completion(KyotoStatusEntry(date: Date(), status: readStatus()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KyotoStatusEntry>) -> Void) {
        let entry = KyotoStatusEntry(date: Date(), status: readStatus())
        // Refresh every 15 minutes; real-time updates come via WidgetCenter.shared.reloadTimelines.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readStatus() -> KyotoNodeConnectionStatus {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let raw = defaults.string(forKey: "kyotoConnectionStatus"),
              let status = KyotoNodeConnectionStatus(rawValue: raw) else {
            return .disconnected
        }
        return status
    }
}

// MARK: - Widget

struct KyotoStatusWidget: Widget {
    let kind = "KyotoStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KyotoStatusProvider()) { entry in
            KyotoStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Kyoto Node")
        .description("Shows the connection status of the Kyoto CBF light client.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget View

private struct KyotoStatusWidgetView: View {
    let entry: KyotoStatusEntry

    var body: some View {
        VStack(spacing: 12) {
            buildIcon()
            buildTitle()
            buildStatusRow()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func buildIcon() -> some View {
        Image(systemName: "network")
            .font(.title)
            .foregroundStyle(statusColor)
    }

    private func buildTitle() -> some View {
        Text("Kyoto Node")
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundStyle(.primary)
    }

    private func buildStatusRow() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .red
        }
    }

    private var statusText: String {
        switch entry.status {
        case .connected:    return "Connected"
        case .connecting:   return "Connecting"
        case .disconnected: return "Disconnected"
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    KyotoStatusWidget()
} timeline: {
    KyotoStatusEntry(date: Date(), status: .connected)
    KyotoStatusEntry(date: Date(), status: .connecting)
    KyotoStatusEntry(date: Date(), status: .disconnected)
}
