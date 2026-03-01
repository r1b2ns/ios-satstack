import Foundation

// MARK: - Wallet model

/// Represents a tracked wallet entry.
struct Wallet: Identifiable {

    let id: UUID

    /// User-defined wallet name.
    var name: String

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

// MARK: - WalletTransaction model

/// A single Bitcoin transaction associated with a wallet (mocked).
struct WalletTransaction: Identifiable {

    let id: UUID

    /// Destination address of the transaction.
    let address: String

    /// Amount transferred, in BTC.
    let valueBTC: Double

    /// Date the transaction was broadcast.
    let date: Date

    /// Truncated address suitable for compact display (e.g. `bc1qxy2kg…x0wlh`).
    var shortAddress: String {
        guard address.count > 18 else { return address }
        return "\(address.prefix(10))…\(address.suffix(6))"
    }

    /// Human-readable relative date (e.g. "2 hours ago").
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

extension WalletTransaction {

    /// Ten mock transactions for preview / placeholder purposes.
    static let mocked: [WalletTransaction] = [
        WalletTransaction(
            id: UUID(), address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            valueBTC: 0.00210000, date: .now.addingTimeInterval(-1 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q8c6fqw2z8pnl0q3qj7x2rkh6vxwnjpz8qk9j3z",
            valueBTC: 0.00045000, date: .now.addingTimeInterval(-3 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
            valueBTC: 0.01200000, date: .now.addingTimeInterval(-7 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q5y2u7gnngl6djrsq0vfk9k7u3ke9aqkrqmne8r",
            valueBTC: 0.00089000, date: .now.addingTimeInterval(-26 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qnp57fy8zjq3uc56mtz8s0spkptfurjp9k77q3d",
            valueBTC: 0.00512000, date: .now.addingTimeInterval(-48 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qhkdrknrwz3cz5f2eue7e7euh5r5q3j8j7m3d3x",
            valueBTC: 0.00033000, date: .now.addingTimeInterval(-72 * 3_600)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qjyp2xa3r7gwrfkjhg2sf9lf68kt2j9mvf0ek0h",
            valueBTC: 0.00750000, date: .now.addingTimeInterval(-5 * 86_400)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1qkk3vk9k6s7zqr4vhv0y8u4q3x2w1e5t6r9p2m",
            valueBTC: 0.00190000, date: .now.addingTimeInterval(-7 * 86_400)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q2vx4wk8h1j3n6r5t7e9y2u0i4o8p3l6m9k2j5",
            valueBTC: 0.02100000, date: .now.addingTimeInterval(-10 * 86_400)
        ),
        WalletTransaction(
            id: UUID(), address: "bc1q9s3d5f7g1h4k8l2m6n0p4r8v2w5x9y3z7a1c4",
            valueBTC: 0.00067000, date: .now.addingTimeInterval(-14 * 86_400)
        )
    ]
}

// MARK: - Protocol

protocol WalletsViewModelProtocol: ObservableObject {
    var uiState: WalletsUiState { get set }
    func showAddWallet()
    func selectWallet(_ id: UUID)
    func deselectWallet()
    func showRenameAlert()
    func updateWalletName(id: UUID, name: String)
}

// MARK: - UiState

struct WalletsUiState {

    /// Ordered list of wallets to display.
    var wallets: [Wallet] = Wallet.mocked

    /// Non-nil while a wallet is selected (detail mode).
    var selectedWalletId: UUID? = nil

    /// Controls whether the "Add Wallet" sheet is presented.
    var isPresentingAddSheet: Bool = false

    /// Controls whether the rename alert is presented.
    var isPresentingRenameAlert: Bool = false

    /// Editable text shown in the rename alert text field.
    var renameText: String = ""

    /// Mock transactions shown in the selected wallet's detail view.
    var transactions: [WalletTransaction] = WalletTransaction.mocked
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

    func selectWallet(_ id: UUID) {
        uiState.selectedWalletId = id
    }

    func deselectWallet() {
        uiState.selectedWalletId = nil
    }

    func showRenameAlert() {
        guard let id = uiState.selectedWalletId,
              let wallet = uiState.wallets.first(where: { $0.id == id }) else { return }
        uiState.renameText = wallet.name
        uiState.isPresentingRenameAlert = true
    }

    func updateWalletName(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let index = uiState.wallets.firstIndex(where: { $0.id == id }) else { return }
        uiState.wallets[index].name = trimmed
    }
}
