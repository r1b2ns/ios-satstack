import UIKit
import UserNotifications
//#if DEBUG
import netfox
//#endif

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

//        #if DEBUG
        NFX.sharedInstance().start()
//        #endif

        // Set up the notification center
        UNUserNotificationCenter.current().delegate = self

        // Re-register for remote notifications if the user has already granted permission.
        // Permission is requested contextually (watch transaction / add wallet), not on launch.
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        return true
    }

    // MARK: - APNs token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert the token to a hexadecimal string
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()

        Log.print.info("✅ APNs token received: \(tokenString)")

        // Save the token to the manager
        APNsTokenManager.shared.saveToken(tokenString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.print.error("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        APNsTokenManager.shared.clearToken()
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Called when a notification arrives while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Log.print.info("📬 Notification received in foreground")
        return [.banner, .sound, .badge]
    }

    // Called when the user interacts with a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        Log.print.info("👆 User interacted with notification")

        let userInfo = response.notification.request.content.userInfo
        Log.print.info("📦 Payload: \(userInfo)")
    }
}
