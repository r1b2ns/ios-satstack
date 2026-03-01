import SwiftUI

// MARK: - Mock content per WidgetItem

extension WidgetItem {

    /// Returns mock display content for this widget.
    ///
    /// `greedAndFearsIndex` uses the `custom` type to demonstrate
    /// that any SwiftUI view can be embedded in a widget.
    /// All other items use the `icon` type with placeholder values.
    var mockType: WidgetType {
        switch self {
        case .greedAndFearsIndex:
            return .custom(view: AnyView(GreedFearMockWidget()))

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

// MARK: - Greed & Fear mock widget

/// A mock SwiftUI view that demonstrates the `custom` widget type.
/// Shows a numeric score, label, and a gradient color band with a position indicator.
private struct GreedFearMockWidget: View {

    private let score: Int = 72
    private let label: String = "Greed"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            buildHeader()
            buildColorBand()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Subviews

    private func buildHeader() -> some View {
        HStack(alignment: .top) {
            buildTitleStack()
            Spacer()
            buildScoreLabel()
        }
    }

    private func buildTitleStack() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Greed & Fear Index")
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }

    private func buildScoreLabel() -> some View {
        Text("\(score)")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(.orange)
    }

    private func buildColorBand() -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                buildGradientCapsule()
                buildIndicator(in: proxy)
            }
        }
        .frame(height: 16)
    }

    private func buildGradientCapsule() -> some View {
        Capsule()
            .fill(LinearGradient(
                colors: [.red, .orange, .yellow, .green],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: 8)
            .padding(.vertical, 4)
    }

    private func buildIndicator(in proxy: GeometryProxy) -> some View {
        let position = proxy.size.width * (Double(score) / 100.0)
        return Circle()
            .fill(.white)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .frame(width: 16, height: 16)
            .offset(x: position - 8)
    }
}
