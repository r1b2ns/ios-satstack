import Foundation

/// `URLProtocol` that intercepts all requests from a `URLSession` configured
/// with `protocolClasses = [MockURLProtocol.self]`, enabling tests without a real network.
///
/// Usage:
/// ```swift
/// MockURLProtocol.requestHandler = { request in
///     let response = HTTPURLResponse(url: request.url!, statusCode: 200, …)!
///     return (response, Data(…))
/// }
/// ```
final class MockURLProtocol: URLProtocol {

    /// Closure called when intercepting a request.
    /// Returns `(HTTPURLResponse, Data)` or throws to simulate a network error.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
