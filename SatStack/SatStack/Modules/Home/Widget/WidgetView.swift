import SwiftUI

/// Renders a single widget card based on its display type and size.
///
/// - For `.icon`: draws a card with an SF Symbol, title, and subtitle.
///   Layout adapts — compact uses a vertical stack, expanded uses a horizontal layout.
/// - For `.custom`: wraps the provided SwiftUI view inside the same card container.
///
/// An optional `cornerIcon` + `onCornerAction` pair renders a tappable icon in the
/// top-right corner of the card (e.g. an info button or a navigation chevron).
struct WidgetView: View {

    let type: WidgetType
    let size: WidgetSize
    let cornerIcon: String?
    let cornerIconColor: Color
    let onCornerAction: (() -> Void)?

    init(
        type: WidgetType,
        size: WidgetSize,
        cornerIcon: String? = nil,
        cornerIconColor: Color = .secondary,
        onCornerAction: (() -> Void)? = nil
    ) {
        self.type = type
        self.size = size
        self.cornerIcon = cornerIcon
        self.cornerIconColor = cornerIconColor
        self.onCornerAction = onCornerAction
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            buildCard()
            buildCornerIcon()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCornerAction?()
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func buildCard() -> some View {
        switch type {
        case .custom(let view):
            buildCustomCard(view: view)
        case .icon(let image, let title, let subtitle, let tintColor):
            buildIconCard(image: image, title: title, subtitle: subtitle, tintColor: tintColor)
        }
    }

    // MARK: - Custom

    private func buildCustomCard(view: AnyView) -> some View {
        AppCard {
            view.frame(maxWidth: .infinity)
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private func buildIconCard(image: Image, title: String, subtitle: String, tintColor: Color) -> some View {
        AppCard {
            Group {
                if size == .expanded {
                    buildExpandedIconLayout(image: image, title: title, subtitle: subtitle, tintColor: tintColor)
                } else {
                    buildCompactIconLayout(image: image, title: title, subtitle: subtitle, tintColor: tintColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        }
    }

    private func buildCompactIconLayout(image: Image, title: String, subtitle: String, tintColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            image
                .font(.largeTitle)
                .foregroundStyle(tintColor)
            AppText(title, style: .headline)
                .lineLimit(1)
            AppText(subtitle, style: .caption, color: .secondary)
                .lineLimit(1)
        }
    }

    private func buildExpandedIconLayout(image: Image, title: String, subtitle: String, tintColor: Color) -> some View {
        HStack(alignment: .center, spacing: 16) {
            image
                .font(.system(size: 40))
                .foregroundStyle(tintColor)
            buildExpandedTextStack(title: title, subtitle: subtitle)
        }
    }

    private func buildExpandedTextStack(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AppText(title, style: .headline)
            AppText(subtitle, style: .subheadline, color: .secondary)
        }
    }

    // MARK: - Corner icon (decorative — tap is handled by the whole card)

    @ViewBuilder
    private func buildCornerIcon() -> some View {
        if let icon = cornerIcon {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(cornerIconColor)
                .padding(10)
        }
    }
}
