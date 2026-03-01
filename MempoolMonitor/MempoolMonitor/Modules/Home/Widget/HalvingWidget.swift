import SwiftUI

// MARK: - Model

/// Computed data for the Next Halving widget.
struct HalvingInfo {

    /// Block height at which the next halving occurs (multiple of 210,000).
    let nextHalvingHeight: Int

    /// Number of blocks remaining until the next halving.
    let blocksUntil: Int

    /// Estimated wall-clock date of the next halving, computed from the average block time.
    let estimatedDate: Date

    /// Fraction of the current halving epoch that has already elapsed (0.0 – 1.0).
    let epochProgress: Double
}

extension HalvingInfo {

    /// Computes next-halving info from a `DifficultyAdjustmentResponse`.
    ///
    /// - Current block height is derived as `nextRetargetHeight − remainingBlocks`.
    /// - Average block time (`timeAvg`, in milliseconds) is used to estimate the date;
    ///   falls back to 600 s (10 min) if the server reports zero.
    static func compute(from difficulty: DifficultyAdjustmentResponse) -> HalvingInfo {
        let halvingInterval   = 210_000
        let currentHeight     = difficulty.nextRetargetHeight - difficulty.remainingBlocks
        let nextHalvingHeight = ((currentHeight / halvingInterval) + 1) * halvingInterval
        let blocksUntil       = nextHalvingHeight - currentHeight

        let avgBlockSeconds   = difficulty.timeAvg > 0
            ? Double(difficulty.timeAvg) / 1_000
            : 600                                   // default: 10 min per block
        let estimatedDate     = Date().addingTimeInterval(Double(blocksUntil) * avgBlockSeconds)

        let blocksIntoEpoch   = currentHeight % halvingInterval
        let epochProgress     = Double(blocksIntoEpoch) / Double(halvingInterval)

        return HalvingInfo(
            nextHalvingHeight: nextHalvingHeight,
            blocksUntil: blocksUntil,
            estimatedDate: estimatedDate,
            epochProgress: epochProgress
        )
    }
}

// MARK: - View

/// Displays next-halving data as a compact card widget.
///
/// Shows the calendar icon, title, estimated days remaining,
/// and a progress bar reflecting how far into the current halving epoch we are.
struct HalvingWidget: View {

    let blocksUntil: Int
    let nextHalvingHeight: Int
    let estimatedDate: Date
    /// Fraction of the current epoch elapsed (0.0 – 1.0).
    let epochProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildIcon()
            buildTitle()
            buildSubtitle()
            buildProgressBar()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
    }

    // MARK: - Builders

    private func buildIcon() -> some View {
        Image(systemName: "calendar.badge.clock")
            .font(.largeTitle)
            .foregroundStyle(Color.purple)
    }

    private func buildTitle() -> some View {
        Text("Next Halving")
            .font(.headline)
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    private func buildSubtitle() -> some View {
        Text(daysLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func buildProgressBar() -> some View {
        ProgressView(value: epochProgress)
            .tint(.purple)
    }

    // MARK: - Computed labels

    /// Human-readable estimate of days remaining until the next halving.
    private var daysLabel: String {
        let seconds = estimatedDate.timeIntervalSinceNow
        guard seconds > 0 else { return "Imminent!" }
        let days = Int(seconds / 86_400)
        return days > 0 ? "~\(days) days" : "< 1 day"
    }
}
