import Foundation

extension UInt64 {

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.generatesDecimalNumbers = false
        return formatter
    }

    /// Returns a compact BIP-177 string representation of a satoshi value.
    ///
    /// - Multiples of 1 000 000 are abbreviated with an `M` suffix (e.g. `2M`).
    /// - Multiples of 1 000 are abbreviated with a `K` suffix (e.g. `500K`).
    /// - All other values are formatted with thousands separators (e.g. `1,234,567`).
    func formattedBip177() -> String {
        if self != .zero && self >= 1_000_000 && self % 1_000_000 == .zero {
            return "\(self / 1_000_000)M"
        } else if self != .zero && self % 1_000 == 0 {
            return "\(self / 1_000)K"
        }
        return numberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
