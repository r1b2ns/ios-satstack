import SwiftUI

/// Lets the user pick the app-wide visual theme.
///
/// Presented via the Settings navigation stack; selecting a row
/// immediately applies the chosen theme to the entire app.
struct ThemeSettingsView: View {

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases) { appTheme in
                    buildThemeRow(appTheme)
                }
            } footer: {
                Text("The selected theme is applied immediately across the entire app.")
                    .font(theme.typography.caption)
            }
        }
        .navigationTitle("Theme")
    }

    // MARK: - Subviews

    private func buildThemeRow(_ appTheme: AppTheme) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                themeManager.current = appTheme
            }
        } label: {
            buildThemeRowContent(appTheme)
        }
        .foregroundStyle(.foreground)
    }

    private func buildThemeRowContent(_ appTheme: AppTheme) -> some View {
        HStack(spacing: 12) {
            buildThemeIcon(appTheme)
            buildThemeLabels(appTheme)
            Spacer()
            buildSelectionIndicator(for: appTheme)
        }
        .padding(.vertical, 4)
    }

    private func buildThemeIcon(_ appTheme: AppTheme) -> some View {
        Image(systemName: appTheme.systemImage)
            .font(.title3)
            .foregroundStyle(theme.colors.accent)
            .frame(width: 28)
    }

    private func buildThemeLabels(_ appTheme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appTheme.displayName)
                .font(theme.typography.subheadline)
                .fontWeight(.medium)
            Text(appTheme.displayDescription)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.contentSecondary)
        }
    }

    @ViewBuilder
    private func buildSelectionIndicator(for appTheme: AppTheme) -> some View {
        if themeManager.current == appTheme {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.colors.accent)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
