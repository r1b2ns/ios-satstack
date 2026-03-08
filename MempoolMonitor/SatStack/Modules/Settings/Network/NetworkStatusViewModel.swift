import Foundation
import Network

// MARK: - Models

/// Connection status for a single network endpoint.
enum ConnectionStatus {
    case checking
    case connected
    case disconnected
}

/// A network endpoint the app connects to, with its live connection status.
struct NetworkEndpoint: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    var status: ConnectionStatus = .checking
}

// MARK: - UI State

struct NetworkStatusUiState {
    var endpoints: [NetworkEndpoint] = []
}

// MARK: - Protocol

protocol NetworkStatusViewModelProtocol: ObservableObject {
    var uiState: NetworkStatusUiState { get set }
    func checkConnectivity() async
}

// MARK: - ViewModel

final class NetworkStatusViewModel: NetworkStatusViewModelProtocol {

    @Published var uiState = NetworkStatusUiState()

    // MARK: - Init

    init() {
        uiState.endpoints = buildEndpoints()
    }

    // MARK: - Connectivity

    /// Pings every endpoint and updates its status individually.
    @MainActor
    func checkConnectivity() async {
        // Reset all to checking
        for index in uiState.endpoints.indices {
            uiState.endpoints[index].status = .checking
        }

        await withTaskGroup(of: (Int, ConnectionStatus).self) { group in
            for (index, endpoint) in uiState.endpoints.enumerated() {
                group.addTask { [weak self] in
                    guard let self else { return (index, .disconnected) }
                    let status = await self.ping(endpoint)
                    return (index, status)
                }
            }

            for await (index, status) in group {
                guard index < uiState.endpoints.count else { continue }
                uiState.endpoints[index].status = status
            }
        }
    }

    // MARK: - Private

    /// Builds the list of endpoints from current configuration.
    private func buildEndpoints() -> [NetworkEndpoint] {
        var endpoints: [NetworkEndpoint] = [
            NetworkEndpoint(
                name: "Esplora API",
                url: BDKNetworkConfig.esploraURL
            ),
            NetworkEndpoint(
                name: "Electrum Server",
                url: BDKNetworkConfig.electrumURL
            ),
            NetworkEndpoint(
                name: "Mempool Explorer",
                url: BDKNetworkConfig.mempoolExplorerURL
            )
        ]

        // Mempool Monitor (custom server from Local.xcconfig)
        if let host = Bundle.main.infoDictionary?["MempoolMonitorHost"] as? String,
           !host.isEmpty {
            endpoints.append(
                NetworkEndpoint(
                    name: "Mempool Monitor",
                    url: "http://\(host)"
                )
            )
        }

        return endpoints
    }

    /// Checks connectivity for a single endpoint.
    private func ping(_ endpoint: NetworkEndpoint) async -> ConnectionStatus {
        if endpoint.url.hasPrefix("ssl://") {
            return await pingTCP(endpoint.url)
        } else {
            return await pingHTTP(endpoint.url)
        }
    }

    /// HTTP/HTTPS connectivity check via a lightweight HEAD request.
    private func pingHTTP(_ urlString: String) async -> ConnectionStatus {
        guard let url = URL(string: urlString) else { return .disconnected }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               (200...399).contains(http.statusCode) {
                return .connected
            }
            return .disconnected
        } catch {
            Log.print.warning("[NetworkStatus] HTTP ping failed for \(urlString): \(error.localizedDescription)")
            return .disconnected
        }
    }

    /// TCP/TLS connectivity check for Electrum-style `ssl://host:port` endpoints.
    private func pingTCP(_ urlString: String) async -> ConnectionStatus {
        // Parse ssl://host:port
        let stripped = urlString.replacingOccurrences(of: "ssl://", with: "")
        let parts = stripped.split(separator: ":")
        guard parts.count == 2,
              let port = UInt16(parts[1]) else {
            return .disconnected
        }
        let host = String(parts[0])

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tls
            )

            let queue = DispatchQueue(label: "network.status.tcp")
            var resumed = false

            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: .connected)

                case .failed, .cancelled:
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: .disconnected)

                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Timeout after 5 seconds
            queue.asyncAfter(deadline: .now() + 5) {
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: .disconnected)
            }
        }
    }
}
