import ActivityKit
import Foundation

// Compiled in both the app and the widget extension.
// The app uses it to start/update the activity; the widget uses it to display.

struct TransactionActivityAttributes: ActivityAttributes {

    // MARK: - Dynamic State (can be updated via push or code)
    struct ContentState: Codable, Hashable {
        var confirmations: Int
        var status: TransactionStatus
        /// Transaction TXID
        var txId: String
        /// Total value transferred in BTC (sum of outputs)
        var valueBtc: Double?
        /// Fee paid in satoshis
        var feeSats: Int?
        /// Estimated time until first confirmation, in minutes (nil when already confirmed)
        var estimatedMinutes: Int?
        /// Sender address (first input address), truncated for display
        var senderAddress: String?
        /// Position of the transaction in the mempool queue
        var blockPosition: BlockPosition?
    }

    // MARK: - Static Data (set at creation, immutable)
    var txId: String
}

// MARK: - Status

enum TransactionStatus: String, Codable, Hashable {
    case pending   = "pending"
    case confirmed = "confirmed"
    case failed    = "failed"
    case notFound  = "notFound"

    var label: String {
        switch self {
        case .pending:   return "Pending"
        case .confirmed: return "Confirmed"
        case .failed:    return "Failed"
        case .notFound:  return "Not Found"
        }
    }
}

// MARK: - BlockPosition

/// Where the transaction sits in the mempool queue.
///
/// - `nextBlock`  — likely to be mined in the very next block
/// - `secondBlock`— likely to be mined two blocks from now
/// - `other`      — further back in the queue (or untracked depth)
enum BlockPosition: String, Codable, Hashable {
    case nextBlock   = "nextBlock"
    case secondBlock = "secondBlock"
    case other       = "other"
}
