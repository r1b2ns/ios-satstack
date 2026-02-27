import ActivityKit
import Foundation

// Compilado tanto no app quanto no widget extension.
// O app usa para iniciar/atualizar a activity; o widget usa para exibir.

struct TransactionActivityAttributes: ActivityAttributes {

    // MARK: - Estado dinâmico (pode ser atualizado via push ou código)
    struct ContentState: Codable, Hashable {
        var confirmations: Int
        var status: TransactionStatus
        /// TXID da transação
        var txId: String
        /// Valor total transferido em BTC (soma dos outputs)
        var valueBtc: Double?
        /// Taxa paga em satoshis
        var feeSats: Int?
    }

    // MARK: - Dados estáticos (definidos na criação, imutáveis)
    var txId: String
}

// MARK: - Status

enum TransactionStatus: String, Codable, Hashable {
    case pending   = "pending"
    case confirmed = "confirmed"
    case failed    = "failed"

    var label: String {
        switch self {
        case .pending:   return "Pendente"
        case .confirmed: return "Confirmada"
        case .failed:    return "Falhou"
        }
    }
}
