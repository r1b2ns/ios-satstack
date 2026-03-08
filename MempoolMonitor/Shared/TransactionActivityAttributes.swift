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
