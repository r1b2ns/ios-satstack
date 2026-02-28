import Foundation
import SwiftUI

protocol SettingsViewModelProtocol: ObservableObject {
    var uiState: SettingsUiState { get set }
}

struct SettingsUiState {
}

final class SettingsViewModel: SettingsViewModelProtocol {
    @Published var uiState: SettingsUiState

    init(uiState: SettingsUiState = .init()) {
        self.uiState = uiState
    }
}
