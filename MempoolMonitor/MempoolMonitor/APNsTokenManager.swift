import Foundation

/// Singleton manager for storing and accessing the APNs device token.
@MainActor
class APNsTokenManager: ObservableObject {
    static let shared = APNsTokenManager()

    @Published private(set) var deviceToken: String?

    private let storage: KeyStorable
    private let tokenKey = "apns_device_token"

    init(storage: KeyStorable = UserDefaultsStorable()) {
        self.storage = storage
        // Load previously saved token on init
        self.deviceToken = storage.string(forKey: tokenKey)
    }

    /// Saves the APNs device token.
    func saveToken(_ token: String) {
        self.deviceToken = token
        storage.set(token, forKey: tokenKey)
        print("💾 APNs token saved: \(token)")
    }

    /// Clears the APNs device token.
    func clearToken() {
        self.deviceToken = nil
        storage.removeObject(forKey: tokenKey)
        print("🗑️ APNs token removed")
    }

    /// Returns the current token or nil.
    func getToken() -> String? {
        return deviceToken
    }

    /// Whether a token is currently available.
    var hasToken: Bool {
        return deviceToken != nil
    }
}
