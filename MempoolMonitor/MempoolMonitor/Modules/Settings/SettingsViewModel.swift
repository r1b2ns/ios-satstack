import Combine
import Foundation
import SwiftUI

protocol SettingsViewModelProtocol: ObservableObject {
    var uiState: SettingsUiState { get set }
}

struct SettingsUiState {
    var hasAPNsToken: Bool = false
}

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
    }
}
