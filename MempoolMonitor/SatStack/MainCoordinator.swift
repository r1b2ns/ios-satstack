import SwiftUI

protocol MainCoordinatorProtocol: ObservableObject {
    var path: NavigationPath { get set }
}

extension MainCoordinatorProtocol {
    func popToRoot() {
        path.removeLast(path.count)
    }
}

class MainCoordinator: MainCoordinatorProtocol {
    @Published var path = NavigationPath()

//    func navigateToModule(_ param: Param) {
//        path.append(param)
//    }
}
