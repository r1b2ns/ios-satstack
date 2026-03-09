import Foundation

// MARK: - Request

/// `GET /blocks/tip/height` — returns the current best block height as a plain integer.
struct GetBlockTipHeightRequest: Requestable {

    typealias Response = Int

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/blocks/tip/height" }
    var method: HTTPMethod { .get }
}
