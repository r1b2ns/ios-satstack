import CoreGraphics

/// Shape and spacing tokens for a theme.
///
/// Centralises corner radii and spacing increments so that every view
/// stays geometrically consistent when the theme changes.
struct ThemeShape {

    // MARK: - Corner radii

    /// Radius used for widget card backgrounds and sheet containers.
    var cornerRadiusCard: CGFloat

    /// Radius used for primary action buttons.
    var cornerRadiusButton: CGFloat

    /// Radius used for inline feedback banners and small containers.
    var cornerRadiusSmall: CGFloat

    // MARK: - Spacing

    /// 4 pt — tight internal padding (badge vertical padding).
    var spacingXS: CGFloat

    /// 8 pt — compact internal padding (badge horizontal padding, small gaps).
    var spacingS: CGFloat

    /// 12 pt — standard gap between sibling views.
    var spacingM: CGFloat

    /// 16 pt — card internal padding, standard horizontal margin.
    var spacingL: CGFloat

    /// 24 pt — large vertical gap between form sections.
    var spacingXL: CGFloat
}
