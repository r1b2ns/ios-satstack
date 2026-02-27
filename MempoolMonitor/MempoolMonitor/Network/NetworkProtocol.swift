import Foundation

/// Abstrai as capacidades de execução de requisições HTTP.
///
/// Conforme este protocolo para criar implementações alternativas de `NetworkManager`,
/// como mocks para testes unitários.
///
/// ```swift
/// struct MockNetworkManager: NetworkProtocol {
///     func perform<R: Requestable>(_ requestable: R) async throws -> R.Response { … }
/// }
/// ```
protocol NetworkProtocol {

    /// Executa `requestable`, valida o status code e retorna a resposta decodificada.
    ///
    /// - Throws: `HTTPError` em caso de falha de rede, status code de erro ou falha de decodificação.
    func perform<R: Requestable>(_ requestable: R) async throws -> R.Response
}
