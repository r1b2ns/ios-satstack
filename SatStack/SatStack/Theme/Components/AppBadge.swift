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

    /// The label displayed inside the badge.
    let text: String

    /// The accent color used for both the tint and the foreground.
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
