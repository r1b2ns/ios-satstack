import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configurar o centro de notificações
        UNUserNotificationCenter.current().delegate = self
        
        // Solicitar autorização para notificações
        Task {
            await requestNotificationAuthorization()
        }
        
        return true
    }
    
    // MARK: - Solicitar autorização
    
    private func requestNotificationAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                print("✅ Autorização de notificações concedida")
                
                // Registrar para notificações remotas na thread principal
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Autorização de notificações negada")
            }
        } catch {
            print("❌ Erro ao solicitar autorização: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Token APNs
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Converter o token para string hexadecimal
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        
        print("✅ Token APNs recebido: \(tokenString)")
        
        // Salvar o token no serviço
        APNsTokenManager.shared.saveToken(tokenString)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Falha ao registrar para notificações remotas: \(error.localizedDescription)")
        APNsTokenManager.shared.clearToken()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Quando a notificação chega com o app em foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("📬 Notificação recebida em foreground")
        return [.banner, .sound, .badge]
    }
    
    // Quando o usuário interage com a notificação
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        print("👆 Usuário interagiu com a notificação")
        
        let userInfo = response.notification.request.content.userInfo
        print("Payload: \(userInfo)")
    }
}
