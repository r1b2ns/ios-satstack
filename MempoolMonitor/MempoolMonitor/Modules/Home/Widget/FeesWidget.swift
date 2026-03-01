import SwiftUI

// MARK: - View

/// Displays recommended Bitcoin transaction fee rates as a compact card widget.
///
/// Shows three fee tiers — fastest, hour, and economy — each labeled and
/// color-coded by urgency.
struct FeesWidget: View {

    /// Fee for next-block confirmation (fastest), in sat/vB.
    let fastestFee: Int

    /// Fee for confirmation within approximately 1 hour, in sat/vB.
    let hourFee: Int

    /// Economy (low-priority) fee rate, in sat/vB.
    let economyFee: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            buildHeader()
            buildFeeRows()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
    }

    // MARK: - Builders

    private func buildHeader() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.headline)
                .foregroundStyle(Color.green)
            Text("Fees")
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
    }

    private func buildFeeRows() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            buildFeeRow(label: "Fast",    value: fastestFee, color: .red)
            buildFeeRow(label: "Hour",    value: hourFee,    color: .orange)
            buildFeeRow(label: "Economy", value: economyFee, color: .green)
        }
    }

    private func buildFeeRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value) sat/vB")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}
