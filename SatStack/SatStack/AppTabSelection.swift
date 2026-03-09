import Foundation

/// Shared observable that controls which tab is visible in the root TabView.
///
/// Inject via `.environmentObject(tabSelection)` at the app root so any view
/// can switch tabs without coupling to the parent hierarchy.
final class AppTabSelection: ObservableObject {
    @Published var selectedTab: Int = 0

    static let home            = 0
    static let wallets         = 1
    static let watching        = 2
    static let settings        = 3
}
