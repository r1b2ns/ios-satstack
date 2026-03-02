import Foundation
import SwiftData

/// Generic SwiftData model that stores any `Codable` value as JSON-encoded `Data`.
///
/// Uniqueness is enforced via the composite key `(typeName, identifier)`.
/// - `typeName`: The Swift type name (e.g., "WatchTransactionResponse").
/// - `identifier`: A caller-provided unique ID within that type.
@Model
final class PersistedItem {

    // MARK: - Stored Properties

    /// Swift type name used to partition stored items (e.g., "WatchTransactionResponse").
    var typeName: String

    /// Unique identifier within the type partition.
    var identifier: String

    /// JSON-encoded representation of the `Codable` value.
    var payload: Data

    /// Timestamp when the item was first persisted.
    var createdAt: Date

    /// Timestamp of the most recent update.
    var updatedAt: Date

    // MARK: - Init

    init(
        typeName: String,
        identifier: String,
        payload: Data,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.typeName = typeName
        self.identifier = identifier
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
