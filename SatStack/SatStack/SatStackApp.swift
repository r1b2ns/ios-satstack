import SwiftData
import SwiftUI
import TipKit
import UIKit

@main
struct SatStackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Drives the app-wide visual theme. Injected into the environment
    /// so every view can read `@Environment(\.appTheme)` or
    /// `@EnvironmentObject var themeManager: ThemeManager`.
    @StateObject private var themeManager = ThemeManager()

    /// Controls the welcome screen shown on first launch.
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenWelcome")

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

        try? Tips.configure()
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
            .fullScreenCover(isPresented: $showWelcome) {
                WelcomeView {
                    UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
                    showWelcome = false
                }
                .environment(\.appTheme, themeManager.definition)
            }
        }
    }
}
