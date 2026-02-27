import SwiftUI

class MainCoordinator: ObservableObject {
    @Published var path = NavigationPath()

//    func navigateToModule(_ param: Param) {
//        path.append(param)
//    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
