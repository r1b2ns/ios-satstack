import Foundation

/// Gerenciador singleton para armazenar e acessar o token APNs
@MainActor
class APNsTokenManager: ObservableObject {
    static let shared = APNsTokenManager()
    
    @Published private(set) var deviceToken: String?
    
    private let tokenKey = "apns_device_token"
    
    private init() {
        // Carregar token salvo do UserDefaults ao inicializar
        self.deviceToken = UserDefaults.standard.string(forKey: tokenKey)
    }
    
    /// Salva o token APNs
    func saveToken(_ token: String) {
        self.deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        print("💾 Token APNs salvo: \(token)")
    }
    
    /// Limpa o token APNs
    func clearToken() {
        self.deviceToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        print("🗑️ Token APNs removido")
    }
    
    /// Retorna o token atual ou nil
    func getToken() -> String? {
        return deviceToken
    }
    
    /// Verifica se há um token disponível
    var hasToken: Bool {
        return deviceToken != nil
    }
}
