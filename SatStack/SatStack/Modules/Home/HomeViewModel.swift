import Foundation
import SwiftUI

// MARK: - Protocol

protocol HomeViewModelProtocol: ObservableObject {
    var uiState: HomeUiState { get set }
    func widgetType(for item: WidgetItem) -> WidgetType
    func addWidget(_ item: WidgetItem)
    func removeWidget(id: UUID)
    func moveWidgets(from: IndexSet, to: Int)
    func refresh() async
}

// MARK: - UiState

struct HomeUiState {
    var activeWidgets: [WidgetConfiguration] = []

    /// Latest Fear and Greed Index entry fetched from the API.
    /// `nil` until the first successful fetch.
    var fearAndGreedEntry: FearAndGreedEntry? = nil

    /// Next halving data computed from the difficulty-adjustment API.
    /// `nil` until the first successful fetch.
    var halvingInfo: HalvingInfo? = nil

    /// Recommended fee rates fetched from the API.
    /// `nil` until the first successful fetch.
    var recommendedFees: RecommendedFeesResponse? = nil

    /// Bitcoin price in multiple fiat currencies fetched from the API.
    /// `nil` until the first successful fetch.
    var bitcoinPrice: PricesResponse? = nil

    /// Total wallet balance in BTC, computed by summing all persisted wallets.
    /// `nil` until the first successful fetch from SwiftData.
    var totalWalletBalanceBTC: Double? = nil

    /// Widgets not yet present in the active list, derived automatically.
    var availableWidgets: [WidgetItem] {
        let activeItems = Set(activeWidgets.map(\.item))
        return WidgetItem.allCases.filter { !activeItems.contains($0) }
    }
}

// MARK: - ViewModel

final class HomeViewModel: HomeViewModelProtocol {
    @Published var uiState: HomeUiState

    private let storage: KeyStorable
    private let storageKey = "home_active_widgets"
    private let api: AlternativeMeAPIProtocol
    private let mempoolSpaceAPI: MempoolSpaceAPIProtocol

    init(
        uiState: HomeUiState = .init(),
        storage: KeyStorable = UserDefaultsStorable(),
        api: AlternativeMeAPIProtocol = AlternativeMeAPI.shared,
        mempoolSpaceAPI: MempoolSpaceAPIProtocol = MempoolSpaceAPI.shared
    ) {
        self.uiState          = uiState
        self.storage          = storage
        self.api              = api
        self.mempoolSpaceAPI  = mempoolSpaceAPI
        loadWidgets()
        Task { @MainActor in await self.fetchFearAndGreedIndex() }
        Task { @MainActor in await self.fetchHalvingInfo() }
        Task { @MainActor in await self.fetchRecommendedFees() }
        Task { @MainActor in await self.loadPersistedBitcoinPrice() }
        Task { @MainActor in await self.fetchBitcoinPrice() }
        Task { @MainActor in await self.fetchWalletBalance() }
    }

    // MARK: - Actions

    /// Returns the display content for a widget item.
    ///
    /// `greedAndFearsIndex` uses live API data when available,
    /// falling back to placeholder values until the first fetch completes.
    /// All other items use placeholder values.
    func widgetType(for item: WidgetItem) -> WidgetType {
        switch item {
        case .greedAndFearsIndex:
            if let entry = uiState.fearAndGreedEntry, let score = Int(entry.value) {
                return .custom(view: AnyView(GreedFearWidget(
                    score: score,
                    label: entry.valueClassification
                )))
            }
            return .custom(view: AnyView(
                GreedFearWidget(score: 72, label: "Greed")
                    .redacted(reason: .placeholder)
            ))

        case .transactionFeeValue:
            if let fees = uiState.recommendedFees {
                return .custom(view: AnyView(FeesWidget(
                    fastestFee: fees.fastestFee,
                    hourFee:    fees.hourFee,
                    economyFee: fees.economyFee
                )))
            }
            return item.mockType

        case .currentBlockHeight:
            if let info = uiState.halvingInfo {
                return .icon(
                    image: Image(systemName: item.systemImage),
                    title: item.displayName,
                    subtitle: Self.formattedBlockHeight(info.currentBlockHeight),
                    tintColor: item.tintColor
                )
            }
            return item.mockType

        case .nextHalving:
            if let info = uiState.halvingInfo {
                return .custom(view: AnyView(HalvingWidget(
                    blocksUntil: info.blocksUntil,
                    nextHalvingHeight: info.nextHalvingHeight,
                    estimatedDate: info.estimatedDate,
                    epochProgress: info.epochProgress
                )))
            }
            return item.mockType

        case .fiatPrice:
            if let price = uiState.bitcoinPrice {
                return .custom(view: AnyView(FiatPriceWidget(usdPrice: price.usd)))
            }
            return item.mockType

        case .walletBalance:
            if let balance = uiState.totalWalletBalanceBTC {
                let formatted = String(format: "₿ %.8f", balance)
                return .icon(
                    image: Image(systemName: item.systemImage),
                    title: item.displayName,
                    subtitle: formatted,
                    tintColor: item.tintColor
                )
            }
            return item.mockType
        }
    }

    // MARK: - Helpers

    /// Returns the block height formatted with thousands separators (e.g. `"892,450"`).
    private static func formattedBlockHeight(_ height: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: height)) ?? "\(height)"
    }

    func addWidget(_ item: WidgetItem) {
        let config = WidgetConfiguration(item: item)
        uiState.activeWidgets.append(config)
        saveWidgets()
    }

    func removeWidget(id: UUID) {
        uiState.activeWidgets.removeAll { $0.id == id }
        saveWidgets()
    }

    func moveWidgets(from source: IndexSet, to destination: Int) {
        uiState.activeWidgets.move(fromOffsets: source, toOffset: destination)
        saveWidgets()
    }

    // MARK: - Refresh

    /// Refreshes all home data concurrently.
    /// Awaiting this method keeps the pull-to-refresh spinner active until all fetches complete.
    @MainActor
    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchFearAndGreedIndex() }
            group.addTask { await self.fetchHalvingInfo() }
            group.addTask { await self.fetchRecommendedFees() }
            group.addTask { await self.fetchBitcoinPrice() }
            group.addTask { await self.fetchWalletBalance() }
        }
    }

    // MARK: - Fear and Greed fetch

    @MainActor
    private func fetchFearAndGreedIndex() async {
        do {
            let response = try await api.fetchFearAndGreedIndex()
            if let entry = response.data.first {
                uiState.fearAndGreedEntry = entry
            }
        } catch {
            Log.print.error("Fear and Greed Index fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Halving fetch

    @MainActor
    private func fetchHalvingInfo() async {
        do {
            let difficulty = try await mempoolSpaceAPI.fetchDifficultyAdjustment()
            uiState.halvingInfo = HalvingInfo.compute(from: difficulty)
        } catch {
            Log.print.error("Halving info fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Recommended fees fetch

    @MainActor
    private func fetchRecommendedFees() async {
        do {
            uiState.recommendedFees = try await mempoolSpaceAPI.fetchRecommendedFees()
        } catch {
            Log.print.error("Recommended fees fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Bitcoin price fetch

    /// Loads the last persisted `PricesResponse` from SwiftData so the widget
    /// shows a value immediately, before the network fetch completes.
    @MainActor
    private func loadPersistedBitcoinPrice() async {
        if let prices = try? await SwiftDataStorable.shared.fetch(
            PricesResponse.self,
            id: "bitcoin_prices"
        ) {
            uiState.bitcoinPrice = prices
            Log.print.info("Bitcoin prices loaded from cache")
        }
    }

    @MainActor
    private func fetchBitcoinPrice() async {
        do {
            let prices = try await mempoolSpaceAPI.fetchPrices()
            uiState.bitcoinPrice = prices
            try await SwiftDataStorable.shared.save(prices, id: "bitcoin_prices")
        } catch {
            Log.print.error("Bitcoin price fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Wallet balance fetch

    /// Loads all persisted wallets from SwiftData and sums their `balanceBTC`.
    @MainActor
    private func fetchWalletBalance() async {
        do {
            let wallets: [Wallet] = try await SwiftDataStorable.shared.fetchAll(Wallet.self)
            let total = wallets.reduce(0.0) { $0 + $1.balanceBTC }
            uiState.totalWalletBalanceBTC = total
        } catch {
            Log.print.error("Wallet balance fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func loadWidgets() {
        if let saved: [WidgetConfiguration] = storage.object(forKey: storageKey) {
            uiState.activeWidgets = saved
        } else {
            uiState.activeWidgets = WidgetConfiguration.defaultActive
        }
    }

    private func saveWidgets() {
        storage.setObject(uiState.activeWidgets, forKey: storageKey)
    }
}
