import Foundation

/// Camada de acesso à API do servidor Mempool Monitor.
///
/// O host é lido em runtime a partir da chave `MempoolMonitorHost` do `Info.plist`,
/// que por sua vez é preenchida pela variável `MEMPOOL_MONITOR_HOST` do `Local.xcconfig`.
///
/// Encapsula todos os endpoints disponíveis e utiliza o `NetworkManager` internamente,
/// expondo métodos de alto nível orientados ao domínio.
///
/// ```swift
/// try await MempoolMonitorAPI.shared.watchTransaction(
///     txId: "abc123…",
///     deviceToken: "deviceHex…",
///     activityToken: "activityHex…"
/// )
/// ```
final class MempoolMonitorAPI: MempoolMonitorAPIProtocol {

    // MARK: - Shared

    static let shared = MempoolMonitorAPI()

    // MARK: - Dependencies

    let baseURL: URL
    private let network: any NetworkProtocol

    // MARK: - Init

    init(
        baseURL: URL = MempoolMonitorAPI.resolvedBaseURL(),
        network: any NetworkProtocol = NetworkManager.shared
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    // MARK: - Private helpers

    /// Lê `MempoolMonitorHost` do Info.plist (injetado pelo xcconfig) e constrói a URL base.
    /// Retorna `http://localhost:3000` como fallback se a chave estiver ausente.
    private static func resolvedBaseURL() -> URL {
        let host = Bundle.main.infoDictionary?["MempoolMonitorHost"] as? String
                   ?? "localhost:3000"
        return URL(string: "http://\(host)")!
    }

    // MARK: - Endpoints

    /// Registra uma transação Bitcoin para monitoramento via push notification e Live Activity.
    ///
    /// - Parameters:
    ///   - txId:          Hash da transação Bitcoin (64 caracteres hex).
    ///   - deviceToken:   Token APNs do dispositivo (hex).
    ///   - activityToken: Token da Live Activity (hex). Omitido do payload quando `nil`.
    func watchTransaction(
        txId: String,
        deviceToken: String,
        activityToken: String?
    ) async throws {
        _ = try await network.perform(
            WatchTransactionRequest(
                baseURL:       baseURL,
                txId:          txId,
                deviceToken:   deviceToken,
                activityToken: activityToken
            )
        )
    }
}
