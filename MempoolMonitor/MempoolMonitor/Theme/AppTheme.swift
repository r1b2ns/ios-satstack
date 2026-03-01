import SwiftUI

// MARK: - Theme enum

/// Identifies the available visual themes.
///
/// Add a new case here to introduce an additional theme; implement its
/// `definition` property to wire up the matching `AppThemeDefinition`.
enum AppTheme: String, CaseIterable, Identifiable, Codable {

    /// Follows the native iOS system appearance.
    case `default`

    /// Bitcoin-orange accent replaces the system blue everywhere.
    case bitcoinOnly

    /// Faithful recreation of the Windows XP Luna theme —
    /// Tahoma font, XP blue accent, ECE9D8 window surfaces, squared corners.
    case windowsXP

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .default:     return "Default"
        case .bitcoinOnly: return "Bitcoin Only"
        case .windowsXP:   return "Windows XP"
        }
    }

    var displayDescription: String {
        switch self {
        case .default:     return "Follows the iOS system appearance"
        case .bitcoinOnly: return "Orange accent — Bitcoin to the core"
        case .windowsXP:   return "Luna blue, Tahoma font, classic XP surfaces"
        }
    }

    var systemImage: String {
        switch self {
        case .default:     return "iphone"
        case .bitcoinOnly: return "bitcoinsign.circle.fill"
        case .windowsXP:   return "desktopcomputer"
        }
    }

    // MARK: - Definition

    /// Returns the full set of tokens for this theme.
    var definition: AppThemeDefinition {
        switch self {
        case .default:     return .defaultTheme
        case .bitcoinOnly: return .bitcoinOnlyTheme
        case .windowsXP:   return .windowsXPTheme
        }
    }
}

// MARK: - Definition container

/// Aggregates all visual tokens for a single theme.
struct AppThemeDefinition {
    let colors: ThemeColors
    let typography: ThemeTypography
    let shape: ThemeShape
}

// MARK: - Theme definitions

extension AppThemeDefinition {

    /// Native iOS appearance — uses system colours, SF Pro typography,
    /// and standard iOS corner-radius values.
    static let defaultTheme = AppThemeDefinition(
        colors: ThemeColors(
            background:          Color(.systemBackground),
            backgroundSecondary: Color(.secondarySystemBackground),
            card:                Color(.secondarySystemBackground),
            contentPrimary:      Color.primary,
            contentSecondary:    Color.secondary,
            contentTertiary:     Color(UIColor.tertiaryLabel),
            accent:              Color.blue,
            accentForeground:    Color.white,
            success:             Color.green,
            warning:             Color.orange,
            destructive:         Color.red,
            widgetFearGreed:     Color.orange,
            widgetBalance:       Color.yellow,
            widgetBlockHeight:   Color.blue,
            widgetFees:          Color.green,
            widgetHalving:       Color.purple
        ),
        typography: ThemeTypography(
            largeTitle:  .largeTitle.bold(),
            title:       .title.bold(),
            headline:    .headline.weight(.semibold),
            subheadline: .subheadline,
            body:        .body,
            caption:     .caption,
            caption2:    .caption2,
            monospaced:  .system(.footnote, design: .monospaced),
            scoreLarge:  .system(size: 48, weight: .bold, design: .rounded)
        ),
        shape: ThemeShape(
            cornerRadiusCard:   16,
            cornerRadiusButton: 14,
            cornerRadiusSmall:  10,
            spacingXS:           4,
            spacingS:            8,
            spacingM:           12,
            spacingL:           16,
            spacingXL:          24
        )
    )

    /// Bitcoin-orange accent — every element that uses blue in the Default
    /// theme is replaced with Bitcoin's signature orange.
    static let bitcoinOnlyTheme = AppThemeDefinition(
        colors: ThemeColors(
            background:          Color(.systemBackground),
            backgroundSecondary: Color(.secondarySystemBackground),
            card:                Color(.secondarySystemBackground),
            contentPrimary:      Color.primary,
            contentSecondary:    Color.secondary,
            contentTertiary:     Color(UIColor.tertiaryLabel),
            accent:              Color.orange,
            accentForeground:    Color.white,
            success:             Color.green,
            warning:             Color.orange,
            destructive:         Color.red,
            widgetFearGreed:     Color.orange,
            widgetBalance:       Color.yellow,
            widgetBlockHeight:   Color.orange,
            widgetFees:          Color.green,
            widgetHalving:       Color.purple
        ),
        typography: ThemeTypography(
            largeTitle:  .largeTitle.bold(),
            title:       .title.bold(),
            headline:    .headline.weight(.semibold),
            subheadline: .subheadline,
            body:        .body,
            caption:     .caption,
            caption2:    .caption2,
            monospaced:  .system(.footnote, design: .monospaced),
            scoreLarge:  .system(size: 48, weight: .bold, design: .rounded)
        ),
        shape: ThemeShape(
            cornerRadiusCard:   16,
            cornerRadiusButton: 14,
            cornerRadiusSmall:  10,
            spacingXS:           4,
            spacingS:            8,
            spacingM:           12,
            spacingL:           16,
            spacingXL:          24
        )
    )

    // MARK: - Windows XP colour helpers

    /// Luna title-bar / interactive blue — #2178E0
    private static let xpBlue    = Color(red: 0.129, green: 0.471, blue: 0.878)
    /// XP window / dialog surface — #ECE9D8
    private static let xpSurface = Color(red: 0.925, green: 0.914, blue: 0.847)
    /// XP raised panel / toolbar background — #D4D0C8
    private static let xpPanel   = Color(red: 0.831, green: 0.816, blue: 0.784)
    /// Start-button green — #13920D
    private static let xpGreen   = Color(red: 0.075, green: 0.573, blue: 0.051)
    /// XP warning orange — #FF9933
    private static let xpOrange  = Color(red: 1.000, green: 0.600, blue: 0.200)
    /// XP gold / dark yellow — #FCCF03
    private static let xpGold    = Color(red: 0.988, green: 0.812, blue: 0.012)
    /// XP destructive red — #CC0000
    private static let xpRed     = Color(red: 0.800, green: 0.000, blue: 0.000)
    /// XP success green — #008000
    private static let xpSuccess = Color(red: 0.000, green: 0.502, blue: 0.000)
    /// XP muted purple for halving widget — #6B238E
    private static let xpPurple  = Color(red: 0.420, green: 0.137, blue: 0.557)

    /// Windows XP Luna — Tahoma font, ECE9D8 surfaces, XP-blue accent,
    /// squared corners (4 pt) and the full Luna colour palette.
    static let windowsXPTheme = AppThemeDefinition(
        colors: ThemeColors(
            background:          xpSurface,
            backgroundSecondary: xpPanel,
            card:                xpSurface,
            contentPrimary:      Color.black,
            contentSecondary:    Color(white: 0.30),
            contentTertiary:     Color(white: 0.50),
            accent:              xpBlue,
            accentForeground:    Color.white,
            success:             xpSuccess,
            warning:             xpOrange,
            destructive:         xpRed,
            widgetFearGreed:     xpOrange,
            widgetBalance:       xpGold,
            widgetBlockHeight:   xpBlue,
            widgetFees:          xpGreen,
            widgetHalving:       xpPurple
        ),
        typography: ThemeTypography(
            // Tahoma — the Windows XP system font (Courier New for monospaced).
            // Falls back to the system font if Tahoma is not available on device.
            largeTitle:  .custom("Tahoma-Bold", size: 34),
            title:       .custom("Tahoma-Bold", size: 28),
            headline:    .custom("Tahoma-Bold", size: 17),
            subheadline: .custom("Tahoma", size: 15),
            body:        .custom("Tahoma", size: 17),
            caption:     .custom("Tahoma", size: 12),
            caption2:    .custom("Tahoma", size: 11),
            monospaced:  .custom("Courier New", size: 13),
            scoreLarge:  .custom("Tahoma-Bold", size: 48)
        ),
        shape: ThemeShape(
            // XP windows and buttons have nearly square corners (3–4 pt).
            cornerRadiusCard:    4,
            cornerRadiusButton:  4,
            cornerRadiusSmall:   2,
            spacingXS:           2,
            spacingS:            4,
            spacingM:            8,
            spacingL:           12,
            spacingXL:          16
        )
    )
}
