import Foundation

/// Executes HTTP/HTTPS requests and decodes responses.
///
/// Accepts any type conforming to `Requestable`. Response body decoding
/// is handled automatically into `R.Response`; use `EmptyResponse` when
/// the endpoint returns no body.
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

    /// Executes `requestable`, validates the status code, and decodes the body as `R.Response`.
    ///
    /// - Throws: `HTTPError` on network failure, HTTP error status code, or decoding failure.
    func perform<R: Requestable>(_ requestable: R) async throws -> R.Response {

        // 1. Build the URLRequest
        let urlRequest: URLRequest
        do {
            urlRequest = try requestable.urlRequest()
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError.invalidURL
        }

        // 2. Log the outgoing request
        PrintProtocol.log(urlRequest)

        // 3. Execute the request
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw HTTPError.networkError(error)
        }

        // 4. Validate the response type and status code
        guard let http = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        if let error = HTTPError.from(statusCode: http.statusCode) {
            throw error
        }

        // 5. Decode the body
        // Endpoints with no body (e.g. 204 No Content) return empty data;
        // replace with `{}` so that `EmptyResponse` decodes without errors.
        do {
            let decodeData = data.isEmpty ? Data("{}".utf8) : data
            return try decoder.decode(R.Response.self, from: decodeData)
        } catch {
            throw HTTPError.decodingError(error)
        }
    }
}
