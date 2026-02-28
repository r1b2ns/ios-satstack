import Foundation

/// Errors that can occur during persistent storage operations.
enum PersistentStorableError: Error, Equatable {
    case encodingFailed
    case decodingFailed
}

/// Abstracts CRUD persistence for any `Codable` type,
/// allowing different backends (SwiftData, Core Data, in-memory, etc.)
/// to be swapped transparently.
///
/// Consumers work exclusively with `Codable` values and never need
/// to import or know about the underlying persistence framework.
protocol PersistentStorable {

    // MARK: - Create / Update

    /// Persists `item` under `id`. Overwrites if an entry with the same type and id already exists.
    func save<T: Codable>(_ item: T, id: String) async throws

    // MARK: - Read

    /// Returns the item of type `T` stored under `id`, or `nil` if not found.
    func fetch<T: Codable>(_ type: T.Type, id: String) async throws -> T?

    /// Returns all items of type `T`.
    func fetchAll<T: Codable>(_ type: T.Type) async throws -> [T]

    // MARK: - Delete

    /// Deletes the item of type `T` stored under `id`.
    /// Does nothing if the item does not exist.
    func delete<T: Codable>(_ type: T.Type, id: String) async throws

    /// Deletes all items of type `T`.
    func deleteAll<T: Codable>(_ type: T.Type) async throws
}
