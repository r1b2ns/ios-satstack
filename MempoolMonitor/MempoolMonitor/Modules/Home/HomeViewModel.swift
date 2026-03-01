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

    init(uiState: HomeUiState = .init(), storage: KeyStorable = UserDefaultsStorable()) {
        self.uiState = uiState
        self.storage = storage
        loadWidgets()
    }

    // MARK: - Actions

    /// Returns the current display content for a widget item.
    ///
    /// Delegates to `mockType` for now; will be replaced with
    /// live API data in a future iteration.
    func widgetType(for item: WidgetItem) -> WidgetType {
        item.mockType
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
