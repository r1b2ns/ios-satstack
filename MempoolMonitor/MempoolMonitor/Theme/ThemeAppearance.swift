import SwiftUI
import UIKit

// MARK: - Modifier

/// Applies the active theme's accent colour to UIKit's global appearance APIs
/// (UITabBar, UINavigationBar) so that every tab icon, navigation back-button,
/// and bar-button item automatically uses the theme colour.
///
/// Attach it once at the root `TabView`:
/// ```swift
/// TabView { … }
///     .applyThemeAppearance(accent: theme.colors.accent)
/// ```
private struct ThemeAppearanceModifier: ViewModifier {

    let accent: Color

    func body(content: Content) -> some View {
        content
            .tint(accent)                          // SwiftUI tint propagation
            .onChange(of: accent) { _, newAccent in
                applyUIKitAppearance(accent: newAccent)
            }
            .onAppear {
                applyUIKitAppearance(accent: accent)
            }
    }

    // MARK: - UIKit appearance

    /// Pushes the accent colour into UIKit's appearance proxies so that
    /// UITabBar and UINavigationBar components that bypass SwiftUI's `.tint()`
    /// propagation also pick up the correct colour.
    private func applyUIKitAppearance(accent: Color) {
        let uiAccent = UIColor(accent)

        applyTabBarAppearance(accent: uiAccent)
        applyNavigationBarAppearance(accent: uiAccent)
    }

    private func applyTabBarAppearance(accent: UIColor) {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Selected item tint
        appearance.stackedLayoutAppearance.selected.iconColor    = accent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.compactInlineLayoutAppearance.selected.iconColor    = accent
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.inlineLayoutAppearance.selected.iconColor    = accent
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = accent
    }

    private func applyNavigationBarAppearance(accent: UIColor) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // Back chevron and back title
        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: accent]

        let backImage = UIImage(systemName: "chevron.left")?
            .withTintColor(accent, renderingMode: .alwaysOriginal)
        appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = accent  // bar button items
    }
}

// MARK: - View extension

extension View {

    /// Applies the active theme accent to UITabBar and UINavigationBar
    /// via both SwiftUI `.tint()` and UIKit appearance APIs.
    func applyThemeAppearance(accent: Color) -> some View {
        modifier(ThemeAppearanceModifier(accent: accent))
    }
}
