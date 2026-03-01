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

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .default:     return "Default"
        case .bitcoinOnly: return "Bitcoin Only"
        }
    }

    var displayDescription: String {
        switch self {
        case .default:     return "Follows the iOS system appearance"
        case .bitcoinOnly: return "Orange accent — Bitcoin to the core"
        }
    }

    var systemImage: String {
        switch self {
        case .default:     return "iphone"
        case .bitcoinOnly: return "bitcoinsign.circle.fill"
        }
    }

    // MARK: - Definition

    /// Returns the full set of tokens for this theme.
    var definition: AppThemeDefinition {
        switch self {
        case .default:     return .defaultTheme
        case .bitcoinOnly: return .bitcoinOnlyTheme
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
}
