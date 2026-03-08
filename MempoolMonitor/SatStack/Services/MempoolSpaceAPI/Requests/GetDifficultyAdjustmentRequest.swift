import Foundation

// MARK: - Response

/// Top-level response for `GET /v1/difficulty-adjustment`.
struct DifficultyAdjustmentResponse: Decodable {

    /// Percentage of the current difficulty epoch that has elapsed (0–100).
    let progressPercent: Double

    /// Expected difficulty change at the next retarget, as a percentage.
    /// Negative values indicate a difficulty decrease.
    let difficultyChange: Double

    /// Unix timestamp of the estimated next retarget.
    let estimatedRetargetDate: Int

    /// Number of blocks remaining until the next retarget.
    let remainingBlocks: Int

    /// Estimated seconds remaining until the next retarget.
    let remainingTime: Int

    /// Difficulty change from the previous retarget, as a percentage.
    let previousRetarget: Double

    /// Unix timestamp of the previous retarget block.
    let previousTime: Int

    /// Block height of the next retarget.
    let nextRetargetHeight: Int

    /// Average time between recent blocks, in milliseconds.
    let timeAvg: Int

    /// Offset between expected and actual block time, in milliseconds.
    let timeOffset: Int

    /// Number of blocks expected to have been mined so far in the epoch.
    /// Returned as a fractional `Double` by the API (e.g. 1436.14).
    let expectedBlocks: Double
}

// MARK: - Request

/// `GET /v1/difficulty-adjustment` — fetches Bitcoin mining difficulty adjustment statistics.
struct GetDifficultyAdjustmentRequest: Requestable {

    typealias Response = DifficultyAdjustmentResponse

    var baseURL: URL       { URL(string: BDKNetworkConfig.esploraURL)! }
    var path: String       { "/v1/difficulty-adjustment" }
    var method: HTTPMethod { .get }
}
