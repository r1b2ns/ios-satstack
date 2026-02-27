import Foundation

/// Executa requisições HTTP/HTTPS e decodifica as respostas.
///
/// Aceita qualquer tipo que conforme `Requestable`. A decodificação do body
/// é feita automaticamente para `R.Response`; use `EmptyResponse` quando
/// o endpoint não retorna body.
///
/// ```swift
/// let response = try await NetworkManager.shared.perform(MyRequest())
/// ```
final class NetworkManager: NetworkProtocol {

    // MARK: - Shared

    static let shared = NetworkManager()

    // MARK: - Dependencies

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    init(
        session: URLSession  = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.decoder = decoder
    }

    // MARK: - Perform

    /// Executa `requestable`, valida o status code e decodifica o body como `R.Response`.
    ///
    /// - Throws: `HTTPError` em caso de falha de rede, status code de erro ou falha de decodificação.
    func perform<R: Requestable>(_ requestable: R) async throws -> R.Response {

        // 1. Monta a URLRequest
        let urlRequest: URLRequest
        do {
            urlRequest = try requestable.urlRequest()
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError.invalidURL
        }

        // 2. Executa a requisição
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw HTTPError.networkError(error)
        }

        // 3. Valida o tipo e o status code da resposta
        guard let http = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        if let error = HTTPError.from(statusCode: http.statusCode) {
            throw error
        }

        // 4. Decodifica o body
        // Endpoints sem body (ex.: 204 No Content) retornam data vazio;
        // substituímos por `{}` para que `EmptyResponse` decodifique sem erros.
        do {
            let decodeData = data.isEmpty ? Data("{}".utf8) : data
            return try decoder.decode(R.Response.self, from: decodeData)
        } catch {
            throw HTTPError.decodingError(error)
        }
    }
}
