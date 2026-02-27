import Foundation

/// Abstrai todos os parâmetros de uma `URLRequest`.
///
/// Basta criar um tipo que conforme este protocolo e o `NetworkManager` se encarrega
/// de montar a requisição, executá-la e decodificar a resposta no tipo `Response`.
///
/// Exemplo de uso:
/// ```swift
/// struct GetUserRequest: Requestable {
///     typealias Response = User
///     var baseURL: URL  { URL(string: "https://api.example.com")! }
///     var path: String  { "/users/\(id)" }
///     var method: HTTPMethod { .get }
///     let id: Int
/// }
///
/// let user = try await NetworkManager.shared.perform(GetUserRequest(id: 42))
/// ```
protocol Requestable {

    /// Tipo da resposta decodificada. Deve ser `Decodable`.
    /// Use `EmptyResponse` para endpoints que não retornam body.
    associatedtype Response: Decodable

    /// URL base (scheme + host + porta). Ex.: `https://api.example.com`
    var baseURL: URL { get }

    /// Caminho do endpoint. Ex.: `/tx/watch`
    var path: String { get }

    /// Método HTTP da requisição.
    var method: HTTPMethod { get }

    /// Headers adicionais. O `Content-Type: application/json` é injetado automaticamente.
    var headers: [String: String] { get }

    /// Query parameters adicionados à URL. Ex.: `[URLQueryItem(name: "limit", value: "10")]`
    var queryItems: [URLQueryItem] { get }

    /// Body da requisição. Qualquer `Encodable` é aceito; `nil` para requisições sem body.
    var body: (any Encodable)? { get }

    /// Timeout em segundos. Default: 30.
    var timeoutInterval: TimeInterval { get }
}

// MARK: - Default values

extension Requestable {
    var headers: [String: String]  { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: (any Encodable)?     { nil }
    var timeoutInterval: TimeInterval { 30 }
}

// MARK: - URLRequest builder

extension Requestable {

    /// Constrói a `URLRequest` completa a partir das propriedades do tipo conformante.
    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw HTTPError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw HTTPError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue

        // Content-Type padrão; pode ser sobrescrito via `headers`
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            // Swift 5.7+ abre o existencial `any Encodable` automaticamente
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }
}

// MARK: - EmptyResponse

/// Tipo de resposta para endpoints que não retornam body (ex.: 204 No Content).
struct EmptyResponse: Decodable {}
