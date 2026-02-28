import Foundation

/// Abstracts all parameters of a `URLRequest`.
///
/// Conform to this protocol and `NetworkManager` takes care of
/// building the request, executing it, and decoding the response into `Response`.
///
/// Example:
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

    /// The decoded response type. Must conform to `Decodable`.
    /// Use `EmptyResponse` for endpoints that return no body.
    associatedtype Response: Decodable

    /// Base URL (scheme + host + port). e.g. `https://api.example.com`
    var baseURL: URL { get }

    /// Endpoint path. e.g. `/tx/watch`
    var path: String { get }

    /// HTTP method of the request.
    var method: HTTPMethod { get }

    /// Additional headers. `Content-Type: application/json` is injected automatically.
    var headers: [String: String] { get }

    /// Query parameters appended to the URL. e.g. `[URLQueryItem(name: "limit", value: "10")]`
    var queryItems: [URLQueryItem] { get }

    /// Request body. Any `Encodable` is accepted; `nil` for requests without a body.
    var body: (any Encodable)? { get }

    /// Timeout in seconds. Default: 30.
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

    /// Builds the complete `URLRequest` from the conforming type's properties.
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

        // Default Content-Type; can be overridden via `headers`
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            // Swift 5.7+ opens the `any Encodable` existential automatically
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }
}

// MARK: - EmptyResponse

/// Response type for endpoints that return no body (e.g. 204 No Content).
struct EmptyResponse: Decodable {}
