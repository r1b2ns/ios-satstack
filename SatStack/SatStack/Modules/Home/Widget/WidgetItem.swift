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
    case fiatPrice

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .greedAndFearsIndex:  return "Greed & Fear Index"
        case .walletBalance:       return "Wallet Balance"
        case .currentBlockHeight:  return "Block Height"
        case .transactionFeeValue: return "Fees"
        case .nextHalving:         return "Next Halving"
        case .fiatPrice:           return "Bitcoin Price"
        }
    }

    var systemImage: String {
        switch self {
        case .greedAndFearsIndex:  return "gauge.with.dots.needle.67percent"
        case .walletBalance:       return "bitcoinsign.circle.fill"
        case .currentBlockHeight:  return "cube.fill"
        case .transactionFeeValue: return "arrow.up.arrow.down"
        case .nextHalving:         return "calendar.badge.clock"
        case .fiatPrice:           return "bitcoinsign.circle.fill"
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
        case .fiatPrice:           return .orange
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

    // MARK: - Corner action

    /// SF Symbol name for the optional top-right corner icon.
    var cornerIcon: String? {
        switch self {
        case .walletBalance:
            return "chevron.right"
        case .greedAndFearsIndex, .nextHalving, .transactionFeeValue, .currentBlockHeight, .fiatPrice:
            return "info.circle"
        }
    }

    /// Foreground color of the corner icon.
    var cornerIconColor: Color {
        self == .walletBalance ? Color(.darkGray) : .secondary
    }

    // MARK: - Info text

    /// Explanatory text shown in the information bottom sheet.
    var infoText: String {
        switch self {
        case .greedAndFearsIndex:
            return "The Crypto Fear & Greed Index measures overall market sentiment on a scale from 0 (Extreme Fear) to 100 (Extreme Greed). Extreme fear can signal a buying opportunity, while extreme greed may indicate the market is overheated and due for a correction."
        case .nextHalving:
            return "Bitcoin halving occurs approximately every four years — every 210,000 blocks — and cuts the block reward miners receive in half. This reduces the rate at which new Bitcoin enters circulation and has historically preceded significant price movements."
        case .transactionFeeValue:
            return "Transaction fees are paid to miners to have your transaction included in the next block. The fee rates shown represent current network demand: faster confirmation requires a higher fee, while economy transactions may take longer during busy periods."
        case .currentBlockHeight:
            return "The block height is the total number of blocks mined since Bitcoin's genesis block (block 0). A new block is added roughly every 10 minutes, each containing a batch of confirmed transactions. It serves as Bitcoin's internal clock."
        case .fiatPrice:
            return "The current Bitcoin price in US Dollars (USD), sourced in real time from public market data. Prices fluctuate continuously on global exchanges based on supply and demand."
        case .walletBalance:
            return ""
        }
    }
}
