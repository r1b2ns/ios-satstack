import SwiftUI

/// A themed card container.
///
/// Wraps its content in the card surface color and corner radius
/// defined by the active theme, so every widget, list item, or panel
/// automatically adapts when the theme changes.
///
/// ```swift
/// AppCard {
///     VStack {
///         Text("Bitcoin")
///         Text("$63,000")
///     }
///     .padding(16)
///     .frame(maxWidth: .infinity, alignment: .leading)
/// }
/// ```
struct AppCard<Content: View>: View {

    @Environment(\.appTheme) private var theme

    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(
                theme.colors.card,
                in: RoundedRectangle(cornerRadius: theme.shape.cornerRadiusCard)
            )
    }
}
