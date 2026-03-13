import Foundation

// MARK: - Response

/// Top-level response for `GET /fng/`.
///
/// `FearAndGreedEntry` is defined in `Shared/FearAndGreedShared.swift`
/// so that both the main app and the widget extension can use it.
struct FearAndGreedIndexResponse: Decodable {
    let name: String
    let data: [FearAndGreedEntry]
    let metadata: FearAndGreedMetadata
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
