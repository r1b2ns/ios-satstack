import SwiftUI

/// Font tokens for a theme.
///
/// Each property maps to a semantic role in the UI so that switching themes
/// can change the typeface, weight, or size of every text element at once.
struct ThemeTypography {

    /// Screen-level titles (e.g. empty-state headings).
    var largeTitle: Font

    /// Section or card titles.
    var title: Font

    /// Widget titles, list row primary labels — slightly smaller than title, semibold.
    var headline: Font

    /// Sub-labels and supporting descriptions below a headline.
    var subheadline: Font

    /// Default body copy.
    var body: Font

    /// Small auxiliary text (confirmations count, secondary info).
    var caption: Font

    /// Extra-small text (status badge labels).
    var caption2: Font

    /// Fixed-width text for transaction IDs and hex strings.
    var monospaced: Font

    /// Large numeric display (e.g. Greed & Fear score).
    var scoreLarge: Font
}
