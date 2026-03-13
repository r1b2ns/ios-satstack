import Foundation

// MARK: - Shared data model

/// A single Fear and Greed Index data point.
///
/// Shared between the main app and the widget extension so both can
/// encode/decode the same representation via App Group UserDefaults.
struct FearAndGreedEntry: Codable {

    /// Numeric score from 0 (Extreme Fear) to 100 (Extreme Greed).
    let value: String

    /// Human-readable classification (e.g. "Extreme Fear", "Greed").
    let valueClassification: String

    /// Unix timestamp of the reading.
    let timestamp: String

    /// Seconds until the next update. Present only on the latest entry.
    let timeUntilUpdate: String?

    enum CodingKeys: String, CodingKey {
        case value
        case valueClassification = "value_classification"
        case timestamp
        case timeUntilUpdate     = "time_until_update"
    }
}

// MARK: - App Group store

/// Lightweight helper for reading/writing data through the App Group UserDefaults
/// shared between the main app and widget extension.
enum AppGroupStore {

    /// The suite name is read from the target's Info.plist (`APP_GROUP_IDENTIFIER`),
    /// which is populated by the xcconfig build setting.
    static let suiteName: String = {
        Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String ?? ""
    }()

    /// App Group UserDefaults instance. Falls back to `.standard` if the suite
    /// name is missing (should not happen in production).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Fear and Greed

    private static let fearAndGreedKey = "widget_fear_and_greed"

    /// Persists the latest Fear and Greed entry so the widget can read it.
    static func saveFearAndGreed(_ entry: FearAndGreedEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: fearAndGreedKey)
    }

    /// Reads the last persisted Fear and Greed entry, if any.
    static func loadFearAndGreed() -> FearAndGreedEntry? {
        guard let data = defaults.data(forKey: fearAndGreedKey) else { return nil }
        return try? JSONDecoder().decode(FearAndGreedEntry.self, from: data)
    }
}
