import Foundation

/// Possible errors in an HTTP request — from the server (4xx/5xx) and the client.
enum HTTPError: LocalizedError {

    // MARK: - 4xx Client Errors
    case badRequest              // 400
    case unauthorized            // 401
    case forbidden               // 403
    case notFound                // 404
    case methodNotAllowed        // 405
    case conflict                // 409
    case unprocessableEntity     // 422
    case tooManyRequests         // 429

    // MARK: - 5xx Server Errors
    case internalServerError     // 500
    case badGateway              // 502
    case serviceUnavailable      // 503
    case gatewayTimeout          // 504

    // MARK: - Client-side Errors
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case unknown(statusCode: Int)

    // MARK: - Factory

    /// Maps an HTTP status code to its corresponding error.
    /// Returns `nil` for successful responses (2xx).
    static func from(statusCode: Int) -> HTTPError? {
        switch statusCode {
        case 200...299: return nil
        case 400:       return .badRequest
        case 401:       return .unauthorized
        case 403:       return .forbidden
        case 404:       return .notFound
        case 405:       return .methodNotAllowed
        case 409:       return .conflict
        case 422:       return .unprocessableEntity
        case 429:       return .tooManyRequests
        case 500:       return .internalServerError
        case 502:       return .badGateway
        case 503:       return .serviceUnavailable
        case 504:       return .gatewayTimeout
        default:        return .unknown(statusCode: statusCode)
        }
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .badRequest:              return "Bad request (400)."
        case .unauthorized:            return "Unauthorized (401)."
        case .forbidden:               return "Forbidden (403)."
        case .notFound:                return "Resource not found (404)."
        case .methodNotAllowed:        return "Method not allowed (405)."
        case .conflict:                return "Request conflict (409)."
        case .unprocessableEntity:     return "Unprocessable entity (422)."
        case .tooManyRequests:         return "Too many requests (429). Try again later."
        case .internalServerError:     return "Internal server error (500)."
        case .badGateway:              return "Bad gateway (502)."
        case .serviceUnavailable:      return "Service unavailable (503)."
        case .gatewayTimeout:          return "Gateway timeout (504)."
        case .invalidURL:              return "Invalid URL."
        case .invalidResponse:         return "Invalid server response."
        case .decodingError(let e):    return "Failed to decode response: \(e.localizedDescription)"
        case .networkError(let e):     return "Network error: \(e.localizedDescription)"
        case .unknown(let code):       return "Unknown error (HTTP \(code))."
        }
    }
}
