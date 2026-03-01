import Foundation

/// Represents a user's widget slot on the Home screen.
///
/// Combines a stable `id` for SwiftUI identity,
/// the `WidgetItem` that determines which widget is displayed,
/// and the `WidgetSize` that controls how much grid space it occupies.
struct WidgetConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    let item: WidgetItem
    var size: WidgetSize

    init(id: UUID = UUID(), item: WidgetItem, size: WidgetSize? = nil) {
        self.id   = id
        self.item = item
        self.size = size ?? item.defaultSize
    }
}
