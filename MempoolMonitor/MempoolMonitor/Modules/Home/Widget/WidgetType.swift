import SwiftUI

/// Defines how a widget renders its content.
///
/// - `custom`: Displays any arbitrary SwiftUI view inside the widget card.
/// - `icon`:   Displays a standard card with an SF Symbol icon, a title, and a subtitle.
///
/// `WidgetType` is intentionally not `Equatable`, `Hashable`, or `Codable` because
/// the `custom` case holds an `AnyView`. Widget identity is always managed through
/// `WidgetConfiguration.id` (a `UUID`).
enum WidgetType {
    /// A widget whose content is provided as an arbitrary SwiftUI view.
    case custom(view: AnyView)
    /// A standard icon-based card with an image, title, subtitle, and an accent color for the icon.
    case icon(image: Image, title: String, subtitle: String, tintColor: Color)
}
