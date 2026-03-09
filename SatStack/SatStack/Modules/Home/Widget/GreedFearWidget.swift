import SwiftUI

/// Displays the Crypto Fear and Greed Index as a card widget.
///
/// Shows the numeric score, the classification label (e.g. "Greed", "Extreme Fear"),
/// and a color band (red → orange → yellow → green) with a white indicator
/// positioned at the corresponding percentage.
struct GreedFearWidget: View {

    /// Numeric score from 0 (Extreme Fear) to 100 (Extreme Greed).
    let score: Int

    /// Human-readable classification returned by the API (e.g. "Greed").
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            buildHeader()
            buildColorBand()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private func buildHeader() -> some View {
        HStack(alignment: .top) {
            buildTitleStack()
            Spacer()
            buildScoreLabel()
        }
    }

    private func buildTitleStack() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            AppText("Greed & Fear Index", style: .headline)
            AppText(label, style: .subheadline, color: .custom(scoreColor))
        }
    }

    private func buildScoreLabel() -> some View {
        AppText("\(score)", style: .scoreLarge, color: .custom(scoreColor))
    }

    // MARK: - Color band

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
        let clamped  = min(max(score, 0), 100)
        let position = proxy.size.width * (Double(clamped) / 100.0)
        return Circle()
            .fill(.white)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .frame(width: 16, height: 16)
            .offset(x: position - 8)
    }

    // MARK: - Score color

    /// Accent color derived from the score, matching the gradient band zones.
    private var scoreColor: Color {
        switch score {
        case 0..<25:  return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        default:      return .green
        }
    }
}
