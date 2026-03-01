import Foundation
import SwiftUI

// MARK: - Protocol

protocol HomeViewModelProtocol: ObservableObject {
    var uiState: HomeUiState { get set }
    func widgetType(for item: WidgetItem) -> WidgetType
    func addWidget(_ item: WidgetItem)
    func removeWidget(id: UUID)
    func moveWidgets(from: IndexSet, to: Int)
}

// MARK: - UiState

struct HomeUiState {
    var activeWidgets: [WidgetConfiguration] = []

    /// Latest Fear and Greed Index entry fetched from the API.
    /// `nil` until the first successful fetch.
    var fearAndGreedEntry: FearAndGreedEntry? = nil

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

    init(
        uiState: HomeUiState = .init(),
        storage: KeyStorable = UserDefaultsStorable(),
        api: AlternativeMeAPIProtocol = AlternativeMeAPI.shared
    ) {
        self.uiState = uiState
        self.storage = storage
        self.api     = api
        loadWidgets()
        Task { @MainActor in await self.fetchFearAndGreedIndex() }
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

        default:
            return item.mockType
        }
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
