import SwiftUI

/// Shows every network endpoint the app connects to with a live connection status indicator.
///
/// Each row displays the endpoint name, its URL, and a coloured circle:
/// - **Gray (pulsing)** — connectivity check in progress
/// - **Green** — connected successfully
/// - **Red** — unreachable
struct NetworkStatusView: View {

    @StateObject private var viewModel = NetworkStatusViewModel()

    var body: some View {
        List {
            buildEndpointsSection()
        }
        .navigationTitle("Network")
        .task {
            await viewModel.checkConnectivity()
        }
    }

    // MARK: - Section

    private func buildEndpointsSection() -> some View {
        Section {
            ForEach(viewModel.uiState.endpoints) { endpoint in
                buildEndpointRow(endpoint)
            }
        } header: {
            Text(BDKNetworkConfig.networkName.capitalized)
        } footer: {
            buildLegend()
        }
    }

    private func buildLegend() -> some View {
        HStack(spacing: 20) {
            buildLegendItem(color: .green, label: "Connected")
            buildLegendItem(color: .red,   label: "Unreachable")
            buildLegendItem(color: .gray,  label: "Checking")
        }
        .padding(.top, 4)
    }

    private func buildLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
        }
    }

    // MARK: - Row

    private func buildEndpointRow(_ endpoint: NetworkEndpoint) -> some View {
        HStack(spacing: 12) {
            buildEndpointLabels(endpoint)
            Spacer()
            buildStatusCircle(endpoint.status)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status circle

    private func buildStatusCircle(_ status: ConnectionStatus) -> some View {
        Circle()
            .fill(circleColor(for: status))
            .frame(width: 10, height: 10)
            .opacity(status == .checking ? 0.5 : 1)
            .animation(
                status == .checking
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: status == .checking
            )
    }

    // MARK: - Labels

    private func buildEndpointLabels(_ endpoint: NetworkEndpoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(endpoint.name)
                .font(.subheadline)
                .fontWeight(.medium)

            #if DEBUG
            Text(endpoint.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            #endif
        }
    }

    // MARK: - Helpers

    private func circleColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .checking:
            return .gray
        case .connected:
            return .green
        case .disconnected:
            return .red
        }
    }
}
