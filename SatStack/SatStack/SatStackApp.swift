import SwiftData
import SwiftUI
import TipKit

@main
struct SatStackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Controls which tab is visible. Injected as an environment object so
    /// any view can switch tabs programmatically (e.g. from a widget action).
    @StateObject private var tabSelection = AppTabSelection()

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
            TabView(selection: $tabSelection.selectedTab) {
                HomeViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Home")
                        } icon: {
                            Image(systemName: "house")
                        }
                    }
                    .tag(AppTabSelection.home)

                WalletsViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Wallets")
                        } icon: {
                            Image(systemName: "creditcard")
                        }
                    }
                    .tag(AppTabSelection.wallets)

                TransactionListViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Watching")
                        } icon: {
                            Image(systemName: "list.bullet")
                        }
                    }
                    .tag(AppTabSelection.watching)

                SettingsViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Settings")
                        } icon: {
                            Image(systemName: "gear")
                        }
                    }
                    .tag(AppTabSelection.settings)
            }
            .environmentObject(tabSelection)
            .modelContainer(modelContainer)
            .sheet(isPresented: $showWelcome) {
                WelcomeView {
                    UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
                    showWelcome = false
                }
                .presentationDetents([.large])
            }
        }
    }
}
