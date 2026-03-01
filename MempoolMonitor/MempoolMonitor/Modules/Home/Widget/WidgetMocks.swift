import SwiftUI

// MARK: - Mock content per WidgetItem

extension WidgetItem {

    /// Returns mock display content for this widget.
    ///
    /// `greedAndFearsIndex` and `nextHalving` use the `custom` type with
    /// redacted placeholder values while live data is loading.
    /// All other items use the `icon` type with static placeholder values.
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
            return .custom(view: AnyView(
                HalvingWidget(
                    blocksUntil: 12_450,
                    nextHalvingHeight: 1_050_000,
                    estimatedDate: Date().addingTimeInterval(89 * 86_400),
                    epochProgress: 0.94
                )
                .redacted(reason: .placeholder)
            ))
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
