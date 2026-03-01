import SwiftData
import SwiftUI
import UIKit

@main
struct MempoolMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

                TransactionListViewFactory.build()
                    .tabItem {
                        Label {
                            Text("Transactions")
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
        }
    }
}
