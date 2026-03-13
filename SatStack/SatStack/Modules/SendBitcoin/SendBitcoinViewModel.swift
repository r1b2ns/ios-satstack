import Foundation
import SwiftUI

// MARK: - FeeOption

/// Available fee-rate tiers for Bitcoin transaction sending.
/// Cases are ordered slow → medium → fast for display purposes.
enum FeeOption: String, CaseIterable, Identifiable {
    case slow
    case medium
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:   return "Fast"
        case .medium: return "Medium"
        case .slow:   return "Slow"
        }
    }

    var icon: String {
        switch self {
        case .fast:   return "hare.fill"
        case .medium: return "figure.walk"
        case .slow:   return "tortoise.fill"
        }
    }

    var estimatedTime: String {
        switch self {
        case .fast:   return "~10 min"
        case .medium: return "~30 min"
        case .slow:   return "~1 hour"
        }
    }
}

// MARK: - SendBitcoinUiState

/// Holds all UI-related state for the Send Bitcoin screen.
struct SendBitcoinUiState {

    /// The destination Bitcoin address entered by the user.
    var address: String = ""

    /// The amount in BTC entered by the user (text to support decimal input).
    var amountText: String = ""

    /// Currently selected fee tier. `nil` until the user picks one.
    var selectedFee: FeeOption? = nil

    /// Recommended fee rates fetched from mempool.space, or `nil` while loading.
    var recommendedFees: RecommendedFeesResponse? = nil

    /// True while the fee rates are being fetched.
    var isLoadingFees: Bool = false

    /// Non-nil when an error should be shown to the user.
    var errorMessage: String? = nil

    /// Controls whether the QR scanner sheet is presented.
    var isPresentingScanner: Bool = false

    /// Controls whether the fee explanation sheet is presented.
    var isPresentingFeeInfo: Bool = false

    /// True while a transaction is being built, signed, and broadcast.
    var isBroadcasting: Bool = false

    /// The txid returned after a successful broadcast, or `nil`.
    var broadcastTxId: String? = nil

    /// True when the broadcast failed and an error alert should be shown.
    var isBroadcastError: Bool = false

    /// Set to `true` to dismiss the entire Send Bitcoin sheet flow.
    var shouldDismiss: Bool = false
}

// MARK: - SendBitcoinViewModelProtocol

protocol SendBitcoinViewModelProtocol: ObservableObject {
    var uiState: SendBitcoinUiState { get set }
    var wallet: Wallet { get }

    /// Fetches recommended fee rates from mempool.space.
    func loadFees() async

    /// Reads the clipboard and populates the address field.
    func pasteAddress()

    /// Processes a scanned QR code result, stripping the `bitcoin:` URI prefix if present.
    func handleScannedCode(_ code: String)

    /// Returns the fee rate in sat/vB for the given option, or `nil` if fees haven't loaded.
    func feeRate(for option: FeeOption) -> Int?

    /// Returns the estimated fee cost in sats for the given option, or `nil` if fees haven't loaded.
    func estimatedFeeSats(for option: FeeOption) -> Int?

    /// True when all fields are valid and the form can be reviewed.
    var isFormValid: Bool { get }

    /// The wallet's balance formatted as a BTC string.
    var formattedBalance: String { get }

    /// True when the address field is non-empty and matches the current network.
    var isAddressValid: Bool { get }

    /// A hint message shown when the address is invalid, or `nil` when valid/empty.
    var addressValidationHint: String? { get }

    /// True when the entered amount exceeds the wallet's available balance.
    var isAmountExceedsBalance: Bool { get }

    /// True when amount + selected fee exceeds the wallet's available balance.
    var isInsufficientFundsWithFee: Bool { get }

    /// Builds, signs, and broadcasts the composed transaction via BDK.
    func broadcastTransaction() async
}

// MARK: - SendBitcoinViewModel

final class SendBitcoinViewModel: SendBitcoinViewModelProtocol {

    @Published var uiState = SendBitcoinUiState()
    let wallet: Wallet

    private let walletService: WalletServiceProtocol
    private let api: MempoolSpaceAPIProtocol
    private let monitorAPI: MempoolMonitorAPIProtocol
    private let liveActivityManager: LiveActivityManager

    /// Average transaction size in virtual bytes for a typical
    /// single-input, two-output (P2WPKH) transaction.
    private let estimatedTxSizeVB: Int = 140

    init(
        wallet: Wallet,
        walletService: WalletServiceProtocol = WalletSyncManager.makeWalletService(),
        api: MempoolSpaceAPIProtocol = MempoolSpaceAPI.shared,
        monitorAPI: MempoolMonitorAPIProtocol = MempoolMonitorAPI.shared,
        liveActivityManager: LiveActivityManager = LiveActivityManager()
    ) {
        self.wallet = wallet
        self.walletService = walletService
        self.api = api
        self.monitorAPI = monitorAPI
        self.liveActivityManager = liveActivityManager
    }

    // MARK: - Fee loading

    @MainActor
    func loadFees() async {
        uiState.isLoadingFees = true
        do {
            let fees = try await api.fetchRecommendedFees()
            uiState.recommendedFees = fees
        } catch {
            Log.print.error("Failed to fetch recommended fees: \(error.localizedDescription)")
            uiState.errorMessage = "Could not load fee estimates."
        }
        uiState.isLoadingFees = false
    }

    // MARK: - Address helpers

    func pasteAddress() {
        guard let clipboard = UIPasteboard.general.string, !clipboard.isEmpty else { return }
        uiState.address = parseBitcoinAddress(from: clipboard)
    }

    func handleScannedCode(_ code: String) {
        uiState.address = parseBitcoinAddress(from: code)
        uiState.isPresentingScanner = false
    }

    // MARK: - Address validation

    /// True when the address field is non-empty and matches the current network.
    var isAddressValid: Bool {
        let address = uiState.address
        guard !address.isEmpty else { return true } // Empty is not invalid, just incomplete
        return Self.validateAddress(address)
    }

    /// A hint message shown when the address doesn't match the network, or `nil` when valid/empty.
    var addressValidationHint: String? {
        let address = uiState.address
        guard !address.isEmpty else { return nil }
        if Self.validateAddress(address) { return nil }

        let networkName = BDKNetworkConfig.networkName
        return "Invalid address for \(networkName)"
    }

    // MARK: - Fee helpers

    /// Returns the fee rate in sat/vB for the given option.
    func feeRate(for option: FeeOption) -> Int? {
        guard let fees = uiState.recommendedFees else { return nil }
        switch option {
        case .fast:   return fees.fastestFee
        case .medium: return fees.halfHourFee
        case .slow:   return fees.hourFee
        }
    }

    /// Returns the estimated total fee in sats for the given option,
    /// based on a typical P2WPKH transaction size (~140 vB).
    func estimatedFeeSats(for option: FeeOption) -> Int? {
        guard let rate = feeRate(for: option) else { return nil }
        return rate * estimatedTxSizeVB
    }

    // MARK: - Amount validation

    /// True when the entered amount exceeds the wallet's available balance.
    var isAmountExceedsBalance: Bool {
        guard let amountBTC = parsedAmountBTC, amountBTC > 0 else { return false }
        return amountBTC > wallet.balanceBTC
    }

    /// True when amount + selected fee exceeds the wallet's available balance.
    var isInsufficientFundsWithFee: Bool {
        guard let amountBTC = parsedAmountBTC, amountBTC > 0 else { return false }
        guard !isAmountExceedsBalance else { return false } // Already caught by amount check
        guard let selectedFee = uiState.selectedFee,
              let feeSats = estimatedFeeSats(for: selectedFee) else { return false }
        let feeBTC = Double(feeSats) / 100_000_000.0
        return (amountBTC + feeBTC) > wallet.balanceBTC
    }

    // MARK: - Form validation

    /// True when all fields are valid and the form can be reviewed.
    var isFormValid: Bool {
        let hasAddress = !uiState.address.isEmpty
        let hasAmount = parsedAmountBTC != nil && (parsedAmountBTC ?? 0) > 0
        let hasFee = uiState.selectedFee != nil
        let hasFees = uiState.recommendedFees != nil
        let addressOk = isAddressValid
        let amountOk = !isAmountExceedsBalance
        let fundsOk = !isInsufficientFundsWithFee

        return hasAddress && hasAmount && hasFee && hasFees && addressOk && amountOk && fundsOk
    }

    /// The wallet's balance formatted in BTC.
    var formattedBalance: String {
        String(format: "%.8f", wallet.balanceBTC)
    }

    // MARK: - Broadcast

    @MainActor
    func broadcastTransaction() async {
        let text = uiState.amountText.replacingOccurrences(of: ",", with: ".")
        guard let rawValue = Double(text),
              let selectedFee = uiState.selectedFee,
              let rate = feeRate(for: selectedFee) else { return }

        let amountBTC: Double
        switch UserDefaults.standard.preferredBalanceFormat {
        case .bitcoin, .fiat: amountBTC = rawValue
        case .sats, .bip177:  amountBTC = rawValue / 100_000_000.0
        }

        let amountSats = UInt64(amountBTC * 100_000_000)

        uiState.isBroadcasting = true
        defer { uiState.isBroadcasting = false }

        do {
            let txid = try await walletService.broadcastTransaction(
                from: wallet,
                to: uiState.address,
                amountSats: amountSats,
                feeRateSatVB: UInt64(rate)
            )
            Log.print.info("[SendBitcoin] Transaction broadcast successfully: \(txid)")
            uiState.broadcastTxId = txid
            await startMonitoring(txId: txid)
        } catch {
            Log.print.error("[SendBitcoin] Broadcast failed: \(error.localizedDescription)")
            uiState.errorMessage = error.localizedDescription
            uiState.isBroadcastError = true
        }
    }

    // MARK: - Monitoring

    /// Starts a Live Activity and registers the transaction with the Mempool Monitor server.
    /// Does not persist anything to SwiftData — monitoring only.
    private func startMonitoring(txId: String) async {
        let activityToken = await liveActivityManager.start(txId: txId)
        let deviceToken = await APNsTokenManager.shared.deviceToken ?? ""
        do {
            let response = try await monitorAPI.watchTransaction(
                txId: txId,
                deviceToken: deviceToken,
                activityToken: activityToken.isEmpty ? nil : activityToken
            )
            await liveActivityManager.update(with: response)
            Log.print.info("[SendBitcoin] Monitoring started for txId: \(txId)")
        } catch {
            Log.print.error("[SendBitcoin] Failed to start monitoring: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    /// The entered amount parsed as a BTC `Double`, or `nil` if invalid.
    /// Converts from the user's preferred balance format (sats/BIP-177 → BTC).
    private var parsedAmountBTC: Double? {
        let text = uiState.amountText.replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty, let value = Double(text) else { return nil }
        switch UserDefaults.standard.preferredBalanceFormat {
        case .bitcoin, .fiat: return value
        case .sats, .bip177:  return value / 100_000_000.0
        }
    }

    /// Strips `bitcoin:` URI scheme and query parameters from a raw string,
    /// returning only the bare Bitcoin address.
    private func parseBitcoinAddress(from input: String) -> String {
        var address = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle BIP-21 URI: bitcoin:<address>?amount=X&label=Y
        if address.lowercased().hasPrefix("bitcoin:") {
            address = String(address.dropFirst("bitcoin:".count))
            if let queryIndex = address.firstIndex(of: "?") {
                address = String(address[..<queryIndex])
            }
        }

        return address
    }

    /// Validates a Bitcoin address against the currently configured network using regex.
    ///
    /// - Mainnet: P2PKH (`1...`), P2SH (`3...`), Bech32/Bech32m (`bc1...`)
    /// - Signet/Testnet: P2PKH (`m.../n...`), P2SH (`2...`), Bech32/Bech32m (`tb1...`)
    private static func validateAddress(_ address: String) -> Bool {
        let pattern: String

        switch BDKNetworkConfig.network {
        case .bitcoin:
            // Mainnet: 1..., 3..., bc1...
            pattern = #"^(1[1-9A-HJ-NP-Za-km-z]{25,34}|3[1-9A-HJ-NP-Za-km-z]{25,34}|bc1[a-zA-HJ-NP-Z0-9]{25,90})$"#

        default:
            // Signet / Testnet: m..., n..., 2..., tb1...
            pattern = #"^([mn2][1-9A-HJ-NP-Za-km-z]{25,34}|tb1[a-zA-HJ-NP-Z0-9]{25,90})$"#
        }

        return address.range(of: pattern, options: .regularExpression) != nil
    }
}
