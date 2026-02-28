import Foundation
import SwiftUI

protocol TransactionListViewModelProtocol: ObservableObject {
    var uiState: TransactionListUiState { get set }
}

struct TransactionListUiState {
    
}

final class TransactionListViewModel: TransactionListViewModelProtocol {
    @Published var uiState: TransactionListUiState
    
    init(uiState: TransactionListUiState = .init()) {
        self.uiState = uiState
    }
}
