import SwiftUI
import UIKit

@main
struct MempoolMonitorApp: App {
    // Conectar o AppDelegate ao SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
