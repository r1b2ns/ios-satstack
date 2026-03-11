import Combine
import Foundation
import SwiftUI

// MARK: - FiatCurrency

enum FiatCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case chf = "CHF"
    case aud = "AUD"
    case jpy = "JPY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: return String(localized: "US Dollar")
        case .eur: return String(localized: "Euro")
        case .gbp: return String(localized: "British Pound")
        case .cad: return String(localized: "Canadian Dollar")
        case .chf: return String(localized: "Swiss Franc")
        case .aud: return String(localized: "Australian Dollar")
        case .jpy: return String(localized: "Japanese Yen")
        }
    }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cad: return "CA$"
        case .chf: return "Fr"
        case .aud: return "A$"
        case .jpy: return "¥"
        }
    }

    var flag: String {
        switch self {
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .cad: return "🇨🇦"
        case .chf: return "🇨🇭"
        case .aud: return "🇦🇺"
        case .jpy: return "🇯🇵"
        }
    }

    /// Extracts the BTC price for this currency from a `PricesResponse`.
    func price(from prices: PricesResponse) -> Double {
        switch self {
        case .usd: return prices.usd
        case .eur: return prices.eur
        case .gbp: return prices.gbp
        case .cad: return prices.cad
        case .chf: return prices.chf
        case .aud: return prices.aud
        case .jpy: return prices.jpy
        }
    }

    /// Formats a price value using this currency's locale-aware number formatter.
    func formattedPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(symbol)\(Int(value))"
    }
}

// MARK: - BalanceDisplayFormat

/// The unit in which wallet balances are displayed throughout the app.
enum BalanceDisplayFormat: String, CaseIterable, Identifiable {

    /// Traditional BTC notation: ₿ 0.12345678
    case bitcoin = "bitcoin"

    /// Satoshi count with "sats" suffix: 12,345,678 sats
    case sats = "sats"

    /// BIP-177 format — satoshi as primary unit, styled with ₿: 12,345,678 ₿
    case bip177 = "bip177"

    /// Fiat equivalent using the user's preferred currency.
    case fiat = "fiat"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bitcoin: return String(localized: "Bitcoin (BTC)")
        case .sats:    return String(localized: "Satoshis (sats)")
        case .bip177:  return String(localized: "BIP-177")
        case .fiat:    return String(localized: "Fiat Currency")
        }
    }

    var example: String {
        switch self {
        case .bitcoin: return "₿ 0.12345678"
        case .sats:    return "12,345,678 sats"
        case .bip177:  return "12,345,678 ₿"
        case .fiat:    return String(localized: "According to preferred currency")
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

// MARK: - UserDefaults + BalanceDisplayFormat

extension UserDefaults {
    private static let preferredBalanceFormatKey = "preferredBalanceFormat"

    var preferredBalanceFormat: BalanceDisplayFormat {
        get {
            let raw = string(forKey: Self.preferredBalanceFormatKey) ?? BalanceDisplayFormat.bitcoin.rawValue
            return BalanceDisplayFormat(rawValue: raw) ?? .bitcoin
        }
        set {
            set(newValue.rawValue, forKey: Self.preferredBalanceFormatKey)
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
    var preferredBalanceFormat: BalanceDisplayFormat = UserDefaults.standard.preferredBalanceFormat
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
                self?.uiState.preferredBalanceFormat = UserDefaults.standard.preferredBalanceFormat
            }
            .store(in: &cancellables)
    }
}
