import Foundation
@testable import MempoolMonitor

/// Implementação fake de `NetworkProtocol` para testes de `MempoolMonitorAPI`.
///
/// Captura a `URLRequest` construída pelo `Requestable` e permite simular
/// erros sem precisar de rede real.
final class MockNetworkManager: NetworkProtocol {

    // MARK: - Configuração

    /// Erro a ser lançado na próxima chamada a `perform`. `nil` → sucesso.
    var stubbedError: Error?

    // MARK: - Captura

    /// Lista de `URLRequest`s construídas, na ordem em que foram realizadas.
    private(set) var capturedRequests: [URLRequest] = []

    /// Quantidade de chamadas a `perform`.
    var callCount: Int { capturedRequests.count }

    // MARK: - NetworkProtocol

    func perform<R: Requestable>(_ requestable: R) async throws -> R.Response {
        // Captura a URLRequest construída pelo Requestable para inspeção nos testes
        capturedRequests.append(try requestable.urlRequest())

        if let error = stubbedError { throw error }

        // Retorna EmptyResponse (ou qualquer Decodable vazio) como resposta padrão
        return try JSONDecoder().decode(R.Response.self, from: Data("{}".utf8))
    }
}
