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
        case .largeTitle:  return .largeTitle
        case .title:       return .title
        case .headline:    return .headline
        case .subheadline: return .subheadline
        case .body:        return .body
        case .caption:     return .caption
        case .caption2:    return .caption2
        case .monospaced:  return .system(.footnote, design: .monospaced)
        case .scoreLarge:  return .system(size: 48, weight: .bold, design: .rounded)
        }
    }

    private var resolvedColor: Color {
        switch color {
        case .primary:          return .primary
        case .secondary:        return .secondary
        case .tertiary:         return Color(UIColor.tertiaryLabel)
        case .accent:           return .accentColor
        case .custom(let c):    return c
        }
    }
}
