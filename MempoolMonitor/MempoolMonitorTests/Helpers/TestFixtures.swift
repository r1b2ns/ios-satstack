import Foundation
import XCTest
@testable import MempoolMonitor

// MARK: - Requestables de teste

/// Requisição GET que espera um `StubResponse` como retorno.
struct StubRequest: Requestable {
    typealias Response = StubResponse
    var baseURL: URL    = URL(string: "https://api.example.com")!
    var path:    String = "/items"
    var method:  HTTPMethod = .get
}

/// Requisição GET sem body que espera `EmptyResponse`.
struct StubEmptyRequest: Requestable {
    typealias Response = EmptyResponse
    var baseURL: URL    = URL(string: "https://api.example.com")!
    var path:    String = "/items"
    var method:  HTTPMethod = .get
}

// MARK: - Response de teste

struct StubResponse: Codable, Equatable {
    let id: Int
}

// MARK: - Helpers de asserção

/// Verifica que `operation` lança um `HTTPError` com a mesma `errorDescription`
/// que `expected`. Falha o teste (via `XCTFail`) caso contrário.
func assertThrowsHTTPError(
    _ expected: HTTPError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail(
            "Esperava HTTPError.\(expected) mas nenhum erro foi lançado",
            file: file, line: line
        )
    } catch let error as HTTPError {
        XCTAssertEqual(
            error.errorDescription,
            expected.errorDescription,
            file: file, line: line
        )
    } catch {
        XCTFail(
            "Esperava HTTPError mas recebeu \(type(of: error)): \(error)",
            file: file, line: line
        )
    }
}

// MARK: - URLResponse factory

extension HTTPURLResponse {
    /// Cria um `HTTPURLResponse` para uma URL fictícia com o status code dado.
    static func stub(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
