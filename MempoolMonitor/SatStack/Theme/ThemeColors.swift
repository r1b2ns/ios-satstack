import SwiftUI

/// Semantic color tokens for a theme.
///
/// All views should read colors from this struct through `@Environment(\.appTheme)`
/// instead of using hardcoded `Color` values, so that switching themes
/// automatically propagates to every screen.
struct ThemeColors {

    // MARK: - Backgrounds

    /// Main window/screen background.
    var background: Color

    /// Grouped or secondary areas (e.g. inside a List row).
    var backgroundSecondary: Color

    /// Surface color for elevated cards and widget containers.
    var card: Color

    // MARK: - Content

    /// Primary text and icons.
    var contentPrimary: Color

    /// Secondary / subdued text and icons.
    var contentSecondary: Color

    /// Tertiary / hint text and decorative icons.
    var contentTertiary: Color

    // MARK: - Accent / Interactive

    /// Brand accent used for buttons, links, and highlighted controls.
    var accent: Color

    /// Foreground drawn on top of `accent` (e.g. button label text).
    var accentForeground: Color

    // MARK: - Status

    /// Success state (confirmed transactions, registered notifications…).
    var success: Color

    /// Warning / in-progress state (pending transactions…).
    var warning: Color

    /// Destructive / error state (failed transactions, errors…).
    var destructive: Color

    // MARK: - Widget tints

    /// Icon tint for the Greed & Fear Index widget.
    var widgetFearGreed: Color

    /// Icon tint for the Wallet Balance widget.
    var widgetBalance: Color

    /// Icon tint for the Block Height widget.
    var widgetBlockHeight: Color

    /// Icon tint for the Transaction Fee widget.
    var widgetFees: Color

    /// Icon tint for the Next Halving widget.
    var widgetHalving: Color
}
