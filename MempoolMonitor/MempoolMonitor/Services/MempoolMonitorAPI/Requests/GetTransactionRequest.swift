import Foundation

/// `GET /tx/{txId}` — fetches the current state of a monitored Bitcoin transaction.
struct GetTransactionRequest: Requestable {

    typealias Response = WatchTransactionResponse

    // MARK: - Input

    let baseURL: URL
    let txId: String

    // MARK: - Requestable

    var path: String     { "/tx/\(txId)" }
    var method: HTTPMethod { .get }
}
