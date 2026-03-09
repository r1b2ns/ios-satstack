import SwiftUI

// MARK: - Primary Button Style

/// Full-width primary action button using the theme accent color.
///
/// Apply it with `.buttonStyle(.appPrimary)`:
///
/// ```swift
/// Button("Watch Transaction") {
///     Task { await viewModel.watchTransaction() }
/// }
/// .buttonStyle(.appPrimary)
/// ```
struct AppPrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.accentColor
                    .opacity(opacity(configuration: configuration)),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundStyle(Color.white)
    }

    private func opacity(configuration: Configuration) -> Double {
        if !isEnabled       { return 0.4 }
        if configuration.isPressed { return 0.8 }
        return 1.0
    }
}

// MARK: - Secondary Button Style

/// Tinted bordered button using the theme accent color.
///
/// Apply it with `.buttonStyle(.appSecondary)`:
///
/// ```swift
/// Button("Paste") { viewModel.paste() }
///     .buttonStyle(.appSecondary)
///     .disabled(!viewModel.uiState.clipboardHasContent)
/// ```
struct AppSecondaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color.accentColor
                    .opacity(backgroundOpacity(configuration: configuration)),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        Color.accentColor.opacity(isEnabled ? 0.5 : 0.2),
                        lineWidth: 1
                    )
            )
            .opacity(isEnabled ? 1 : 0.5)
    }

    private func backgroundOpacity(configuration: Configuration) -> Double {
        configuration.isPressed ? 0.15 : 0.08
    }
}

// MARK: - Convenience extensions

extension ButtonStyle where Self == AppPrimaryButtonStyle {
    /// Full-width primary button styled with the active theme's accent color.
    static var appPrimary: AppPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == AppSecondaryButtonStyle {
    /// Tinted bordered button styled with the active theme's accent color.
    static var appSecondary: AppSecondaryButtonStyle { .init() }
}
