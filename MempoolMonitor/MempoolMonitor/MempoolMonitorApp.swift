import SwiftData
import SwiftUI
import UIKit

@main
struct MempoolMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Drives the app-wide visual theme. Injected into the environment
    /// so every view can read `@Environment(\.appTheme)` or
    /// `@EnvironmentObject var themeManager: ThemeManager`.
    @StateObject private var themeManager = ThemeManager()

    /// Shared ModelContainer for SwiftData persistence.
    /// Created once at app launch; the schema includes only `PersistedItem`.
    private let modelContainer: ModelContainer

    init() {
        do {
            let container = try ModelContainer(for: PersistedItem.self)
            self.modelContainer = container
            SwiftDataStorable.shared = SwiftDataStorable(modelContainer: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Home")
                        } icon: {
                            Image(systemName: "house")
                        }
                    }

                WalletsViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Wallets")
                        } icon: {
                            Image(systemName: "creditcard")
                        }
                    }
                
                TransactionListViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Watching")
                        } icon: {
                            Image(systemName: "list.bullet")
                        }
                    }

                SettingsViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Settings")
                        } icon: {
                            Image(systemName: "gear")
                        }
                    }
            }
            .modelContainer(modelContainer)
            .environmentObject(themeManager)
            .environment(\.appTheme, themeManager.definition)
            .applyThemeAppearance(accent: themeManager.definition.colors.accent)
        }
    }
}
