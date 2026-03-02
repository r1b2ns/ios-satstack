import SwiftUI

/// Visual theme applied to a wallet card, defining its color, icon and label.
enum WalletTheme: String, CaseIterable, Codable {
    case watchOnly
    case bitcoin
    case satsCard

    // MARK: - Display

    var displayName: String {
        switch self {
        case .watchOnly: return "Watch-Only"
        case .bitcoin:   return "Bitcoin"
        case .satsCard:  return "SatsCard"
        }
    }

    var systemImage: String {
        switch self {
        case .watchOnly: return "eye.circle.fill"
        case .bitcoin:   return "bitcoinsign.circle.fill"
        case .satsCard:  return "creditcard.fill"
        }
    }

    // MARK: - Gradient

    /// Background gradient used on the wallet card.
    var gradient: LinearGradient {
        switch self {
        case .watchOnly:
            return LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.27, blue: 0.37),
                    Color(red: 0.30, green: 0.55, blue: 0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .bitcoin:
            return LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.58, blue: 0.10),
                    Color(red: 0.95, green: 0.35, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .satsCard:
            return LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.49, blue: 0.92),
                    Color(red: 0.46, green: 0.29, blue: 0.64)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
