import Foundation

/// Erros possíveis em uma requisição HTTP — tanto do servidor (4xx/5xx) quanto do cliente.
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

    /// Mapeia um status code HTTP para o erro correspondente.
    /// Retorna `nil` para respostas de sucesso (2xx).
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
        case .badRequest:              return "Requisição inválida (400)."
        case .unauthorized:            return "Não autorizado (401)."
        case .forbidden:               return "Acesso negado (403)."
        case .notFound:                return "Recurso não encontrado (404)."
        case .methodNotAllowed:        return "Método não permitido (405)."
        case .conflict:                return "Conflito na requisição (409)."
        case .unprocessableEntity:     return "Entidade não processável (422)."
        case .tooManyRequests:         return "Muitas requisições (429). Tente novamente mais tarde."
        case .internalServerError:     return "Erro interno do servidor (500)."
        case .badGateway:              return "Bad Gateway (502)."
        case .serviceUnavailable:      return "Serviço indisponível (503)."
        case .gatewayTimeout:          return "Tempo limite do gateway (504)."
        case .invalidURL:              return "URL inválida."
        case .invalidResponse:         return "Resposta inválida do servidor."
        case .decodingError(let e):    return "Erro ao decodificar resposta: \(e.localizedDescription)"
        case .networkError(let e):     return "Erro de rede: \(e.localizedDescription)"
        case .unknown(let code):       return "Erro desconhecido (HTTP \(code))."
        }
    }
}
