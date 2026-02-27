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
                
                Text("List Transactions")
                    .tabItem {
                        Label {
                            Text("Transactions")
                        } icon: {
                            Image(systemName: "list.dash")
                        }
                    }
                
                Text("Settings")
                    .tabItem {
                        Label {
                            Text("Settings")
                        } icon: {
                            Image(systemName: "settings")
                        }
                    }
            }
        }
    }
}
