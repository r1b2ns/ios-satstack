import SwiftUI

/// A pill-shaped status badge.
///
/// Uses the theme's caption2 font and applies a translucent tinted background
/// with a matching foreground label — the same visual language as iOS status pills.
///
/// ```swift
/// AppBadge(text: transaction.status.label, tint: statusColor)
/// ```
struct AppBadge: View {

    @Environment(\.appTheme) private var theme

    /// The label displayed inside the badge.
    let text: String

    /// The accent color used for both the tint and the foreground.
    let tint: Color

    var body: some View {
        Text(text)
            .font(theme.typography.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, theme.shape.spacingS)
            .padding(.vertical, theme.shape.spacingXS)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
