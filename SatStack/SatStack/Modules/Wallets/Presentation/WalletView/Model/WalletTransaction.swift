import Combine
import Foundation

/// A single Bitcoin transaction associated with a wallet.
struct WalletTransaction: Identifiable, Codable {

    let id: UUID

    /// Transaction ID or destination address.
    let address: String

    /// Net amount in BTC from the wallet's perspective (positive = received, negative = sent).
    let valueBTC: Double

    /// Date the transaction was broadcast or confirmed.
    let date: Date

    /// Whether the transaction has been included in a confirmed block.
    let isConfirmed: Bool

    /// Truncated identifier suitable for compact display (e.g. `bc1qxy2kg…x0wlh`).
    var shortAddress: String {
        guard address.count > 18 else { return address }
        return "\(address.prefix(6))…\(address.suffix(6))"
    }

    /// Human-readable relative date (e.g. "2 hours ago").
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// Whether this transaction is incoming (received) from the wallet's perspective.
    var isReceived: Bool { valueBTC >= 0 }

    /// Formatted BTC value with sign prefix (e.g. "+₿ 0.00210" or "−₿ 0.00067").
    var formattedValue: String {
        let sign = valueBTC >= 0 ? "+" : ""
        return "\(sign)₿ \(String(format: "%.5f", valueBTC))"
    }
}

extension WalletTransaction {

    /// Ten fixture transactions used by `MockWalletService`.
    static let mocked: [WalletTransaction] = [
        WalletTransaction(id: UUID(), address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                          valueBTC:  0.00210000, date: .now.addingTimeInterval(-1 * 3_600), isConfirmed: false),
        WalletTransaction(id: UUID(), address: "bc1q8c6fqw2z8pnl0q3qj7x2rkh6vxwnjpz8qk9j3z",
                          valueBTC:  0.00045000, date: .now.addingTimeInterval(-3 * 3_600), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
                          valueBTC:  0.01200000, date: .now.addingTimeInterval(-7 * 3_600), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1q5y2u7gnngl6djrsq0vfk9k7u3ke9aqkrqmne8r",
                          valueBTC:  0.00089000, date: .now.addingTimeInterval(-26 * 3_600), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1qnp57fy8zjq3uc56mtz8s0spkptfurjp9k77q3d",
                          valueBTC:  0.00512000, date: .now.addingTimeInterval(-48 * 3_600), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1qhkdrknrwz3cz5f2eue7e7euh5r5q3j8j7m3d3x",
                          valueBTC:  0.00033000, date: .now.addingTimeInterval(-72 * 3_600), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1qjyp2xa3r7gwrfkjhg2sf9lf68kt2j9mvf0ek0h",
                          valueBTC:  0.00750000, date: .now.addingTimeInterval(-5 * 86_400), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1qkk3vk9k6s7zqr4vhv0y8u4q3x2w1e5t6r9p2m",
                          valueBTC:  0.00190000, date: .now.addingTimeInterval(-7 * 86_400), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1q2vx4wk8h1j3n6r5t7e9y2u0i4o8p3l6m9k2j5",
                          valueBTC:  0.02100000, date: .now.addingTimeInterval(-10 * 86_400), isConfirmed: true),
        WalletTransaction(id: UUID(), address: "bc1q9s3d5f7g1h4k8l2m6n0p4r8v2w5x9y3z7a1c4",
                          valueBTC: -0.00067000, date: .now.addingTimeInterval(-14 * 86_400), isConfirmed: true)
    ]
}
