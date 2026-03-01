import SwiftUI

// MARK: - Style

/// Semantic text roles available in the app.
enum AppTextStyle {
    /// Screen-level titles.
    case largeTitle
    /// Section or card titles.
    case title
    /// Widget titles and list primary labels (semibold).
    case headline
    /// Supporting descriptions below a headline.
    case subheadline
    /// Default body copy.
    case body
    /// Small auxiliary text.
    case caption
    /// Extra-small badge labels.
    case caption2
    /// Fixed-width text for transaction IDs.
    case monospaced
    /// Large numeric display (e.g. Greed & Fear score).
    case scoreLarge
}

// MARK: - Color role

/// Semantic foreground color roles.
enum AppTextColor {
    case primary
    case secondary
    case tertiary
    case accent
    /// Use a fully custom color when semantic roles don't apply.
    case custom(Color)
}

// MARK: - View

/// A themed text view.
///
/// Reads font and color tokens from the active theme so that
/// typographic changes propagate automatically to every screen.
///
/// ```swift
/// AppText("Block Height", style: .headline)
/// AppText("3 confirmations", style: .caption, color: .secondary)
/// AppText(txId, style: .monospaced, color: .secondary)
///     .lineLimit(1)
///     .truncationMode(.middle)
/// ```
struct AppText: View {

    @Environment(\.appTheme) private var theme

    private let text: String
    private let style: AppTextStyle
    private let color: AppTextColor

    init(_ text: String, style: AppTextStyle = .body, color: AppTextColor = .primary) {
        self.text  = text
        self.style = style
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(resolvedFont)
            .foregroundStyle(resolvedColor)
    }

    // MARK: - Resolved tokens

    private var resolvedFont: Font {
        switch style {
        case .largeTitle:  return theme.typography.largeTitle
        case .title:       return theme.typography.title
        case .headline:    return theme.typography.headline
        case .subheadline: return theme.typography.subheadline
        case .body:        return theme.typography.body
        case .caption:     return theme.typography.caption
        case .caption2:    return theme.typography.caption2
        case .monospaced:  return theme.typography.monospaced
        case .scoreLarge:  return theme.typography.scoreLarge
        }
    }

    private var resolvedColor: Color {
        switch color {
        case .primary:          return theme.colors.contentPrimary
        case .secondary:        return theme.colors.contentSecondary
        case .tertiary:         return theme.colors.contentTertiary
        case .accent:           return theme.colors.accent
        case .custom(let c):    return c
        }
    }
}
