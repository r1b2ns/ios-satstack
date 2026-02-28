import Foundation
import SwiftUI

protocol HomeViewModelProtocol: ObservableObject {
    var uiState: HomeUiState { get set }
}

struct HomeUiState {
}

final class HomeViewModel: HomeViewModelProtocol {
    @Published var uiState: HomeUiState

    init(uiState: HomeUiState = .init()) {
        self.uiState = uiState
    }
}
