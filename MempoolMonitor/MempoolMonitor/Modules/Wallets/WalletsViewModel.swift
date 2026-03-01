import Foundation

// MARK: - Model

/// Represents a tracked wallet entry.
struct Wallet: Identifiable {

    let id: UUID

    /// User-defined wallet name.
    let name: String

    /// Visual theme that determines the card appearance.
    let theme: WalletTheme

    /// Current balance in BTC (mocked).
    let balanceBTC: Double
}

extension Wallet {

    /// Pre-populated mock wallets used until real wallet management is implemented.
    static let mocked: [Wallet] = [
        Wallet(id: UUID(), name: "Cold Storage",   theme: .watchOnly, balanceBTC: 1.24780000),
        Wallet(id: UUID(), name: "Daily Spending", theme: .bitcoin,   balanceBTC: 0.00420000),
        Wallet(id: UUID(), name: "SatsCard #001",  theme: .satsCard,  balanceBTC: 0.10000000)
    ]
}

// MARK: - Protocol

protocol WalletsViewModelProtocol: ObservableObject {
    var uiState: WalletsUiState { get set }
    func showAddWallet()
}

// MARK: - UiState

struct WalletsUiState {

    /// Ordered list of wallets to display.
    var wallets: [Wallet] = Wallet.mocked

    /// Controls whether the "Add Wallet" sheet is presented.
    var isPresentingAddSheet: Bool = false
}

// MARK: - ViewModel

final class WalletsViewModel: WalletsViewModelProtocol {

    @Published var uiState: WalletsUiState

    init(uiState: WalletsUiState = .init()) {
        self.uiState = uiState
    }

    func showAddWallet() {
        uiState.isPresentingAddSheet = true
    }
}
