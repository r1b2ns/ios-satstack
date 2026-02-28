import Foundation
import XCTest
@testable import MempoolMonitor

// MARK: - Test Requestables

/// GET request that expects a `StubResponse` as return.
struct StubRequest: Requestable {
    typealias Response = StubResponse
    var baseURL: URL    = URL(string: "https://api.example.com")!
    var path:    String = "/items"
    var method:  HTTPMethod = .get
}

/// GET request without body that expects `EmptyResponse`.
struct StubEmptyRequest: Requestable {
    typealias Response = EmptyResponse
    var baseURL: URL    = URL(string: "https://api.example.com")!
    var path:    String = "/items"
    var method:  HTTPMethod = .get
}

// MARK: - Test Response

struct StubResponse: Codable, Equatable {
    let id: Int
}

// MARK: - Assertion Helpers

/// Verifies that `operation` throws an `HTTPError` with the same `errorDescription`
/// as `expected`. Fails the test (via `XCTFail`) otherwise.
func assertThrowsHTTPError(
    _ expected: HTTPError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail(
            "Expected HTTPError.\(expected) but no error was thrown",
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
            "Expected HTTPError but received \(type(of: error)): \(error)",
            file: file, line: line
        )
    }
}

// MARK: - URLResponse factory

extension HTTPURLResponse {
    /// Creates an `HTTPURLResponse` for a dummy URL with the given status code.
    static func stub(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
