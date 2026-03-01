import SwiftUI

// MARK: - Mock content per WidgetItem

extension WidgetItem {

    /// Returns mock display content for this widget.
    ///
    /// `greedAndFearsIndex` uses the `custom` type with placeholder values;
    /// all other items use the `icon` type with placeholder values.
    var mockType: WidgetType {
        switch self {
        case .greedAndFearsIndex:
            return .custom(view: AnyView(GreedFearWidget(score: 72, label: "Greed")))

        case .walletBalance:
            return .icon(
                image: Image(systemName: "bitcoinsign.circle.fill"),
                title: "Wallet Balance",
                subtitle: "₿ 0.00420000",
                tintColor: tintColor
            )

        case .currentBlockHeight:
            return .icon(
                image: Image(systemName: "cube.fill"),
                title: "Block Height",
                subtitle: "840,123",
                tintColor: tintColor
            )

        case .transactionFeeValue:
            return .icon(
                image: Image(systemName: "arrow.up.arrow.down"),
                title: "Transaction Fee",
                subtitle: "12 sat/vB",
                tintColor: tintColor
            )

        case .nextHalving:
            return .icon(
                image: Image(systemName: "calendar.badge.clock"),
                title: "Next Halving",
                subtitle: "~89 days",
                tintColor: tintColor
            )
        }
    }
}

// MARK: - Default active widget list

extension WidgetConfiguration {

    /// The initial widget layout shown to new users.
    ///
    /// `greedAndFearsIndex` is expanded (full row);
    /// the remaining four widgets are compact (two per row).
    static let defaultActive: [WidgetConfiguration] = [
        WidgetConfiguration(item: .greedAndFearsIndex),   // .expanded (default)
        WidgetConfiguration(item: .currentBlockHeight),   // .compact  (default)
        WidgetConfiguration(item: .transactionFeeValue),  // .compact  (default)
        WidgetConfiguration(item: .walletBalance),        // .compact  (default)
        WidgetConfiguration(item: .nextHalving),          // .compact  (default)
    ]
}
