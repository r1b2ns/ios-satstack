import SwiftUI

// MARK: - Factory

struct HomeViewFactory {
    /// Module entry point.
    /// Returns a view that internally manages the lifecycle of the coordinator and viewModel.
    static func build() -> some View {
        HomeEntry()
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
private struct HomeEntry: View {
    @StateObject private var coordinator = HomeCoordinator()
    @StateObject private var viewModel   = HomeViewModel()

    var body: some View {
        HomeView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct HomeView<ViewModel: HomeViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: HomeCoordinator

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            buildContent()
                .navigationTitle("Home")
                .toolbar { buildToolbar() }
                .sheet(isPresented: $coordinator.showCustomizeWidgets) {
                    buildCustomizeSheet()
                }
                .navigationDestinations()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func buildContent() -> some View {
        if viewModel.uiState.activeWidgets.isEmpty {
            buildEmptyState()
        } else {
            buildGrid()
        }
    }

    private func buildGrid() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(groupedRows, id: \.first?.id) { row in
                    buildWidgetRow(row)
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    /// Groups active widgets into rows for display.
    ///
    /// - `.expanded` widgets occupy an entire row on their own.
    /// - `.compact` widgets are paired two per row.
    private var groupedRows: [[WidgetConfiguration]] {
        var rows: [[WidgetConfiguration]] = []
        var compactPair: [WidgetConfiguration] = []

        for config in viewModel.uiState.activeWidgets {
            if config.size == .expanded {
                if !compactPair.isEmpty {
                    rows.append(compactPair)
                    compactPair = []
                }
                rows.append([config])
            } else {
                compactPair.append(config)
                if compactPair.count == 2 {
                    rows.append(compactPair)
                    compactPair = []
                }
            }
        }
        if !compactPair.isEmpty {
            rows.append(compactPair)
        }
        return rows
    }

    @ViewBuilder
    private func buildWidgetRow(_ row: [WidgetConfiguration]) -> some View {
        HStack(spacing: 12) {
            ForEach(row) { config in
                WidgetView(
                    type: viewModel.widgetType(for: config.item),
                    size: config.size
                )
            }
            // Keeps a lone compact widget at half-width instead of stretching full row
            if row.count == 1, row[0].size == .compact {
                Color.clear
            }
        }
    }

    private func buildEmptyState() -> some View {
        ContentUnavailableView(
            "No Widgets",
            systemImage: "square.grid.2x2",
            description: Text("Tap the grid icon to add widgets to your home.")
        )
    }

    // MARK: - Customize sheet

    private func buildCustomizeSheet() -> some View {
        CustomizeWidgetsView(
            activeWidgets: viewModel.uiState.activeWidgets,
            availableWidgets: viewModel.uiState.availableWidgets,
            onAdd: { viewModel.addWidget($0) },
            onRemove: { indexSet in
                for index in indexSet {
                    viewModel.removeWidget(id: viewModel.uiState.activeWidgets[index].id)
                }
            },
            onMove: { viewModel.moveWidgets(from: $0, to: $1) }
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                coordinator.presentCustomizeWidgets()
            } label: {
                Image(systemName: "square.grid.2x2")
            }
        }
    }
}

// MARK: - Navigation destinations

private extension View {
    @ViewBuilder
    func navigationDestinations() -> some View {
        self.navigationDestination(for: HomeRoute.self) { _ in
        }
    }
}
