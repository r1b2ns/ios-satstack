import SwiftUI

/// A generic bottom sheet that displays a title and a body of text.
///
/// - The title uses the same font as a large navigation bar title.
/// - The text accepts `AttributedString` to support rich formatting.
///
/// ```swift
/// .sheet(item: $selectedItem) { item in
///     SheetInformationView(title: item.title, text: item.attributedDescription)
/// }
/// ```
struct SheetInformationView: View {

    let title: String
    let text: AttributedString

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                buildTitle()
                buildText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Builders

    private func buildTitle() -> some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private func buildText() -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}
