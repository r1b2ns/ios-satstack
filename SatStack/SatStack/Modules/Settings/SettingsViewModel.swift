import Combine
import Foundation
import SwiftUI

// MARK: - FiatCurrency

enum FiatCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case brl = "BRL"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .brl: return "Brazilian Real"
        }
    }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .brl: return "R$"
        }
    }

    var flag: String {
        switch self {
        case .usd: return "🇺🇸"
        case .brl: return "🇧🇷"
        }
    }
}

// MARK: - UserDefaults + FiatCurrency

extension UserDefaults {
    private static let preferredCurrencyKey = "preferredFiatCurrency"

    var preferredFiatCurrency: FiatCurrency {
        get {
            let raw = string(forKey: Self.preferredCurrencyKey) ?? FiatCurrency.usd.rawValue
            return FiatCurrency(rawValue: raw) ?? .usd
        }
        set {
            set(newValue.rawValue, forKey: Self.preferredCurrencyKey)
        }
    }
}

// MARK: - Protocol

protocol SettingsViewModelProtocol: ObservableObject {
    var uiState: SettingsUiState { get set }
}

// MARK: - UiState

struct SettingsUiState {
    var hasAPNsToken: Bool = false
    var preferredCurrency: FiatCurrency = UserDefaults.standard.preferredFiatCurrency
}

// MARK: - ViewModel

final class SettingsViewModel: SettingsViewModelProtocol {
    @Published var uiState: SettingsUiState

    private let tokenManager: APNsTokenManager
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    init(
        uiState: SettingsUiState = .init(),
        tokenManager: APNsTokenManager = .shared
    ) {
        self.uiState = uiState
        self.tokenManager = tokenManager
        self.uiState.hasAPNsToken = tokenManager.hasToken

        tokenManager.$deviceToken
            .receive(on: RunLoop.main)
            .map { $0 != nil }
            .sink { [weak self] hasToken in
                self?.uiState.hasAPNsToken = hasToken
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.uiState.preferredCurrency = UserDefaults.standard.preferredFiatCurrency
            }
            .store(in: &cancellables)
    }
}
