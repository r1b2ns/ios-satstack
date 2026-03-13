import Foundation

// MARK: - Fear and Greed shared model

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

// MARK: - Recommended fees shared model

/// Lightweight representation of recommended fee rates shared via App Group.
struct SharedRecommendedFees: Codable {
    let fastestFee: Int
    let hourFee: Int
    let economyFee: Int
}

// MARK: - Halving shared model

/// Lightweight representation of halving data shared via App Group.
struct SharedHalvingInfo: Codable {
    let currentBlockHeight: Int
    let nextHalvingHeight: Int
    let blocksUntil: Int
    /// Estimated halving date stored as `timeIntervalSince1970`.
    let estimatedDateTimestamp: Double
    let epochProgress: Double
}

// MARK: - Fiat price shared model

/// Lightweight representation of Bitcoin prices shared via App Group.
struct SharedPrices: Codable {
    let usd: Double
    let eur: Double
    let gbp: Double
    let cad: Double
    let chf: Double
    let aud: Double
    let jpy: Double
    /// The user's preferred currency code (e.g. "USD").
    let preferredCurrencyCode: String

    /// Returns the price for the user's preferred currency.
    var preferredPrice: Double {
        switch preferredCurrencyCode {
        case "EUR": return eur
        case "GBP": return gbp
        case "CAD": return cad
        case "CHF": return chf
        case "AUD": return aud
        case "JPY": return jpy
        default:    return usd
        }
    }

    /// Formats the preferred currency price using locale-aware number formatting.
    var formattedPreferredPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = preferredCurrencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: preferredPrice)) ?? "\(Int(preferredPrice))"
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

    // MARK: - Recommended Fees

    private static let feesKey = "widget_recommended_fees"

    static func saveFees(_ fees: SharedRecommendedFees) {
        guard let data = try? JSONEncoder().encode(fees) else { return }
        defaults.set(data, forKey: feesKey)
    }

    static func loadFees() -> SharedRecommendedFees? {
        guard let data = defaults.data(forKey: feesKey) else { return nil }
        return try? JSONDecoder().decode(SharedRecommendedFees.self, from: data)
    }

    // MARK: - Halving

    private static let halvingKey = "widget_halving_info"

    static func saveHalving(_ info: SharedHalvingInfo) {
        guard let data = try? JSONEncoder().encode(info) else { return }
        defaults.set(data, forKey: halvingKey)
    }

    static func loadHalving() -> SharedHalvingInfo? {
        guard let data = defaults.data(forKey: halvingKey) else { return nil }
        return try? JSONDecoder().decode(SharedHalvingInfo.self, from: data)
    }

    // MARK: - Fiat Prices

    private static let pricesKey = "widget_fiat_prices"

    static func savePrices(_ prices: SharedPrices) {
        guard let data = try? JSONEncoder().encode(prices) else { return }
        defaults.set(data, forKey: pricesKey)
    }

    static func loadPrices() -> SharedPrices? {
        guard let data = defaults.data(forKey: pricesKey) else { return nil }
        return try? JSONDecoder().decode(SharedPrices.self, from: data)
    }
}
