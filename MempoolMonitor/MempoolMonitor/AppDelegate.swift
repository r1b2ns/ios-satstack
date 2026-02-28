import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Set up the notification center
        UNUserNotificationCenter.current().delegate = self

        // Request notification authorization
        Task {
            await requestNotificationAuthorization()
        }

        return true
    }

    // MARK: - Request authorization

    private func requestNotificationAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                print("✅ Notification authorization granted")

                // Register for remote notifications on the main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Notification authorization denied")
            }
        } catch {
            print("❌ Error requesting authorization: \(error.localizedDescription)")
        }
    }

    // MARK: - APNs token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert the token to a hexadecimal string
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()

        print("✅ APNs token received: \(tokenString)")

        // Save the token to the manager
        APNsTokenManager.shared.saveToken(tokenString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        APNsTokenManager.shared.clearToken()
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Called when a notification arrives while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("📬 Notification received in foreground")
        return [.banner, .sound, .badge]
    }

    // Called when the user interacts with a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        print("👆 User interacted with notification")

        let userInfo = response.notification.request.content.userInfo
        print("Payload: \(userInfo)")
    }
}
