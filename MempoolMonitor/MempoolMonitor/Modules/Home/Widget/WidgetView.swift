import SwiftUI

/// Renders a single widget card based on its display type and size.
///
/// - For `.icon`: draws a card with an SF Symbol, title, and subtitle.
///   Layout adapts — compact uses a vertical stack, expanded uses a horizontal layout.
/// - For `.custom`: wraps the provided SwiftUI view inside the same card container.
struct WidgetView: View {

    let type: WidgetType
    let size: WidgetSize

    var body: some View {
        switch type {
        case .custom(let view):
            buildCustomCard(view: view)
        case .icon(let image, let title, let subtitle, let tintColor):
            buildIconCard(image: image, title: title, subtitle: subtitle, tintColor: tintColor)
        }
    }

    // MARK: - Custom

    private func buildCustomCard(view: AnyView) -> some View {
        view
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Icon

    @ViewBuilder
    private func buildIconCard(image: Image, title: String, subtitle: String, tintColor: Color) -> some View {
        Group {
            if size == .expanded {
                buildExpandedIconLayout(image: image, title: title, subtitle: subtitle, tintColor: tintColor)
            } else {
                buildCompactIconLayout(image: image, title: title, subtitle: subtitle, tintColor: tintColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func buildCompactIconLayout(image: Image, title: String, subtitle: String, tintColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            image
                .font(.largeTitle)
                .foregroundStyle(tintColor)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
