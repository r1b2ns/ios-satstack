import Foundation

/// Defines how much horizontal space a widget occupies in the home grid.
enum WidgetSize: String, Codable {
    /// Occupies one grid column — two compact widgets fit side by side.
    case compact
    /// Occupies both grid columns — one expanded widget spans the full row.
    case expanded
}
