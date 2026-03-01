import Foundation

// MARK: - Response

/// Top-level response for `GET /fng/`.
struct FearAndGreedIndexResponse: Decodable {
    let name: String
    let data: [FearAndGreedEntry]
    let metadata: FearAndGreedMetadata
}

/// A single Fear and Greed Index data point.
struct FearAndGreedEntry: Decodable {

    /// Numeric score from 0 (Extreme Fear) to 100 (Extreme Greed).
    let value: String

    /// Human-readable classification (e.g. "Extreme Fear", "Greed").
    let valueClassification: String

    /// Unix timestamp of the reading.
    let timestamp: String

    /// Seconds until the next update. Present only on the latest entry.
    let timeUntilUpdate: String?

    enum CodingKeys: String, CodingKey {
        case value
        case valueClassification = "value_classification"
        case timestamp
        case timeUntilUpdate     = "time_until_update"
    }
}

/// API-level error wrapper returned in every response.
struct FearAndGreedMetadata: Decodable {
    let error: String?
}

// MARK: - Request

/// `GET /fng/` — fetches the latest Crypto Fear and Greed Index from Alternative.me.
struct GetFearAndGreedIndexRequest: Requestable {

    typealias Response = FearAndGreedIndexResponse

    var baseURL: URL       { URL(string: "https://api.alternative.me")! }
    var path: String       { "/fng/" }
    var method: HTTPMethod { .get }
}
