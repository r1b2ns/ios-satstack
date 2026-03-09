import SwiftData
import SwiftUI
import TipKit

@main
struct SatStackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
            .fullScreenCover(isPresented: $showWelcome) {
                WelcomeView {
                    UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
                    showWelcome = false
                }
            }
        }
    }
}
