import Foundation

// MARK: - Response

/// Top-level response for `GET /v1/prices`.
struct PricesResponse: Codable {

    /// Unix timestamp of the price snapshot.
    let time: Int

    /// Price in US dollars.
    let usd: Double

    /// Price in euros.
    let eur: Double

    /// Price in British pounds.
    let gbp: Double

    /// Price in Canadian dollars.
    let cad: Double

    /// Price in Swiss francs.
    let chf: Double

    /// Price in Australian dollars.
    let aud: Double

    /// Price in Japanese yen.
    let jpy: Double

    enum CodingKeys: String, CodingKey {
        case time
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case cad = "CAD"
        case chf = "CHF"
        case aud = "AUD"
        case jpy = "JPY"
    }
}

// MARK: - Request

/// `GET /v1/prices` — fetches the current Bitcoin price in multiple fiat currencies.
struct GetPricesRequest: Requestable {

    typealias Response = PricesResponse

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/v1/prices" }
    var method: HTTPMethod { .get }
}
