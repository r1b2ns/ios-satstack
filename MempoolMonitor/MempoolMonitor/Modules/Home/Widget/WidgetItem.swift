import SwiftUI

/// Identifies each available widget on the Home screen.
///
/// `WidgetItem` is `Codable` so that the active widget list can be persisted,
/// and `CaseIterable` so the customization screen can enumerate all options.
enum WidgetItem: String, CaseIterable, Codable, Hashable, Identifiable {
    case greedAndFearsIndex
    case walletBalance
    case currentBlockHeight
    case transactionFeeValue
    case nextHalving

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .greedAndFearsIndex:  return "Greed & Fear Index"
        case .walletBalance:       return "Wallet Balance"
        case .currentBlockHeight:  return "Block Height"
        case .transactionFeeValue: return "Transaction Fee"
        case .nextHalving:         return "Next Halving"
        }
    }

    var systemImage: String {
        switch self {
        case .greedAndFearsIndex:  return "gauge.with.dots.needle.67percent"
        case .walletBalance:       return "bitcoinsign.circle.fill"
        case .currentBlockHeight:  return "cube.fill"
        case .transactionFeeValue: return "arrow.up.arrow.down"
        case .nextHalving:         return "calendar.badge.clock"
        }
    }

    /// The accent color used for the widget icon.
    var tintColor: Color {
        switch self {
        case .greedAndFearsIndex:  return .orange
        case .walletBalance:       return .yellow
        case .currentBlockHeight:  return .blue
        case .transactionFeeValue: return .green
        case .nextHalving:         return .purple
        }
    }

    // MARK: - Default size

    /// The default grid size for this widget.
    /// Individual widgets can override this in their `WidgetConfiguration`.
    var defaultSize: WidgetSize {
        switch self {
        case .greedAndFearsIndex: return .expanded
        default:                  return .compact
        }
    }
}
