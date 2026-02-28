import SwiftUI
import UIKit

@main
struct MempoolMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
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
        }
    }
}
