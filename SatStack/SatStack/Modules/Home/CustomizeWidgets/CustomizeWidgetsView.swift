import SwiftUI

/// A sheet that lets the user manage their Home widget layout.
///
/// Displays two sections:
/// - **Active** — current widgets, reorderable by drag and removable by swipe.
/// - **Add Widgets** — remaining widgets that are not yet on the Home screen.
///
/// The view is always in edit mode so drag handles and delete controls
/// are immediately visible without requiring a separate Edit button.
struct CustomizeWidgetsView: View {

    let activeWidgets: [WidgetConfiguration]
    let availableWidgets: [WidgetItem]
    let onAdd: (WidgetItem) -> Void
    let onRemove: (IndexSet) -> Void
    let onMove: (IndexSet, Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                buildActiveSection()
                buildAvailableSection()
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                buildOKButton()
            }
        }
        .presentationDragIndicator(.automatic)
        .presentationDetents([.medium, .large])
    }

    // MARK: - OK button

    private func buildOKButton() -> some View {
        Button("OK") { dismiss() }
            .buttonStyle(.appPrimary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    // MARK: - Sections

    @ViewBuilder
    private func buildActiveSection() -> some View {
        if !activeWidgets.isEmpty {
            Section("Active") {
                ForEach(activeWidgets) { config in
                    buildActiveRow(config)
                }
                .onDelete(perform: onRemove)
                .onMove(perform: onMove)
            }
        }
    }

    @ViewBuilder
    private func buildAvailableSection() -> some View {
        if !availableWidgets.isEmpty {
            Section("Add Widgets") {
                ForEach(availableWidgets) { item in
                    buildAvailableRow(item)
                }
            }
        }
    }

    // MARK: - Rows

    private func buildActiveRow(_ config: WidgetConfiguration) -> some View {
        HStack(spacing: 12) {
            Image(systemName: config.item.systemImage)
                .frame(width: 28)
                .foregroundStyle(config.item.tintColor)
            Text(config.item.displayName)
        }
    }

    private func buildAvailableRow(_ item: WidgetItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .frame(width: 28)
                .foregroundStyle(item.tintColor)
            Text(item.displayName)
            Spacer()
            Button {
                onAdd(item)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

}
