import SwiftUI

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppThemeDefinition = .defaultTheme
}

// MARK: - EnvironmentValues extension

extension EnvironmentValues {

    /// The active theme definition, propagated from the root `WindowGroup`
    /// via `.environment(\.appTheme, themeManager.definition)`.
    ///
    /// Any view can read it with:
    /// ```swift
    /// @Environment(\.appTheme) private var theme
    /// ```
    var appTheme: AppThemeDefinition {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
