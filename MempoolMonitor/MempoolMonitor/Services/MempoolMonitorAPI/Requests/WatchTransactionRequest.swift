import Foundation

/// `POST /tx/watch` — registra uma transação Bitcoin para monitoramento.
struct WatchTransactionRequest: Requestable {

    typealias Response = EmptyResponse

    // MARK: - Input

    let baseURL:       URL
    let txId:          String
    let deviceToken:   String
    let activityToken: String?  // nil → omitido do JSON pelo encoder

    // MARK: - Requestable

    var path:   String    { "/tx/watch" }
    var method: HTTPMethod { .post }

    var body: (any Encodable)? {
        Payload(txId: txId, deviceToken: deviceToken, activityToken: activityToken)
    }

    // MARK: - Private

    private struct Payload: Encodable {
        let txId:          String
        let deviceToken:   String
        let activityToken: String?  // `nil` → chave ausente no JSON
    }
}
