import Foundation

/// `POST /tx/watch` — registers a Bitcoin transaction for monitoring.
struct WatchTransactionRequest: Requestable {

    typealias Response = EmptyResponse

    // MARK: - Input

    let baseURL:       URL
    let txId:          String
    let deviceToken:   String
    let activityToken: String?  // nil → omitted from JSON by the encoder

    // MARK: - Requestable

    var path:   String     { "/tx/watch" }
    var method: HTTPMethod { .post }

    var body: (any Encodable)? {
        Payload(txId: txId, deviceToken: deviceToken, activityToken: activityToken)
    }

    // MARK: - Private

    private struct Payload: Encodable {
        let txId:          String
        let deviceToken:   String
        let activityToken: String?  // `nil` → key absent from JSON
    }
}
