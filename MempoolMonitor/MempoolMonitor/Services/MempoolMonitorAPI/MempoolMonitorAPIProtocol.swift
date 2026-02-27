import Foundation

/// Abstrai as capacidades da camada de acesso à API do Mempool Monitor.
///
/// Conforme este protocolo para criar implementações alternativas de `MempoolMonitorAPI`,
/// como mocks para testes unitários.
///
/// ```swift
/// struct MockMempoolMonitorAPI: MempoolMonitorAPIProtocol {
///     func watchTransaction(txId: String, deviceToken: String, activityToken: String?) async throws { … }
/// }
/// ```
protocol MempoolMonitorAPIProtocol {

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
    ) async throws
}
