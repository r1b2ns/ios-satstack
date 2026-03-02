import Combine
import SwiftUI

/// Observable store that holds the currently active `AppTheme`.
///
/// Inject it at the app root and propagate via `.environmentObject(themeManager)`
/// and `.environment(\.appTheme, themeManager.definition)`:
///
/// ```swift
/// @StateObject private var themeManager = ThemeManager()
///
/// WindowGroup {
///     ContentView()
///         .environmentObject(themeManager)
///         .environment(\.appTheme, themeManager.definition)
/// }
/// ```
///
/// Any view that needs to **read or change** the theme can declare:
/// ```swift
/// @EnvironmentObject private var themeManager: ThemeManager
/// ```
final class ThemeManager: ObservableObject {

    // MARK: - State

    /// The currently active theme. Changing this value immediately
    /// re-renders every view that reads `@Environment(\.appTheme)`.
    @Published var current: AppTheme {
        didSet { persist() }
    }

    // MARK: - Derived

    /// The resolved token set for the current theme.
    var definition: AppThemeDefinition { current.definition }

    // MARK: - Storage

    private static let storageKey = "app_theme"

    // MARK: - Init

    init() {
        let saved  = UserDefaults.standard.string(forKey: Self.storageKey)
        self.current = AppTheme(rawValue: saved ?? "") ?? .default
    }

    // MARK: - Private

    private func persist() {
        UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
    }
}
