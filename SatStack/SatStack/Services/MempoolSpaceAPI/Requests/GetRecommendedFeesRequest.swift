import Foundation

// MARK: - Response

/// Top-level response for `GET /v1/fees/recommended`.
struct RecommendedFeesResponse: Decodable {

    /// Fastest confirmation fee rate, in sat/vB (typically next block).
    let fastestFee: Int

    /// Fee rate for confirmation within approximately 30 minutes, in sat/vB.
    let halfHourFee: Int

    /// Fee rate for confirmation within approximately 1 hour, in sat/vB.
    let hourFee: Int

    /// Low-priority economy fee rate, in sat/vB.
    let economyFee: Int

    /// Minimum relay fee rate accepted by the network, in sat/vB.
    let minimumFee: Int
}

// MARK: - Request

/// `GET /v1/fees/recommended` — fetches the current recommended Bitcoin transaction fee rates.
struct GetRecommendedFeesRequest: Requestable {

    typealias Response = RecommendedFeesResponse

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/v1/fees/recommended" }
    var method: HTTPMethod { .get }
}
