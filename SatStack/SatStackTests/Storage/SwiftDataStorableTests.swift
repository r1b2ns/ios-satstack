import XCTest
import SwiftData
@testable import SatStack

final class SwiftDataStorableTests: XCTestCase {

    // MARK: - SUT

    private var sut: SwiftDataStorable!
    private var container: ModelContainer!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: PersistedItem.self, configurations: config)
        sut = SwiftDataStorable(modelContainer: container)
    }

    override func tearDown() {
        sut = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Save & Fetch

    func test_save_and_fetch_roundTripsCodable() async throws {
        let model = CodableStub(name: "Bitcoin", value: 21_000_000)
        try await sut.save(model, id: "btc")

        let retrieved = try await sut.fetch(CodableStub.self, id: "btc")
        XCTAssertEqual(retrieved, model)
    }

    func test_fetch_returnsNil_whenItemDoesNotExist() async throws {
        let result = try await sut.fetch(CodableStub.self, id: "missing")
        XCTAssertNil(result)
    }

    // MARK: - Upsert

    func test_save_updatesExistingItem_whenIdMatches() async throws {
        let original = CodableStub(name: "Bitcoin", value: 21_000_000)
        try await sut.save(original, id: "btc")

        let updated = CodableStub(name: "Bitcoin", value: 42_000_000)
        try await sut.save(updated, id: "btc")

        let retrieved = try await sut.fetch(CodableStub.self, id: "btc")
        XCTAssertEqual(retrieved?.value, 42_000_000)
    }

    // MARK: - FetchAll

    func test_fetchAll_returnsAllItemsOfType() async throws {
        try await sut.save(CodableStub(name: "A", value: 1), id: "1")
        try await sut.save(CodableStub(name: "B", value: 2), id: "2")
        try await sut.save(CodableStub(name: "C", value: 3), id: "3")

        let results = try await sut.fetchAll(CodableStub.self)
        XCTAssertEqual(results.count, 3)
    }

    func test_fetchAll_returnsEmpty_whenNoItemsExist() async throws {
        let results = try await sut.fetchAll(CodableStub.self)
        XCTAssertTrue(results.isEmpty)
    }

    func test_fetchAll_doesNotReturnItemsOfDifferentType() async throws {
        try await sut.save(CodableStub(name: "A", value: 1), id: "1")
        try await sut.save(AnotherCodableStub(label: "X"), id: "1")

        let stubs = try await sut.fetchAll(CodableStub.self)
        XCTAssertEqual(stubs.count, 1)

        let others = try await sut.fetchAll(AnotherCodableStub.self)
        XCTAssertEqual(others.count, 1)
    }

    // MARK: - Delete

    func test_delete_removesSpecificItem() async throws {
        try await sut.save(CodableStub(name: "A", value: 1), id: "1")
        try await sut.save(CodableStub(name: "B", value: 2), id: "2")

        try await sut.delete(CodableStub.self, id: "1")

        let deleted = try await sut.fetch(CodableStub.self, id: "1")
        XCTAssertNil(deleted)

        let remaining = try await sut.fetch(CodableStub.self, id: "2")
        XCTAssertNotNil(remaining)
    }

    func test_delete_doesNotThrow_whenItemDoesNotExist() async throws {
        try await sut.delete(CodableStub.self, id: "nonexistent")
    }

    // MARK: - DeleteAll

    func test_deleteAll_removesAllItemsOfType() async throws {
        try await sut.save(CodableStub(name: "A", value: 1), id: "1")
        try await sut.save(CodableStub(name: "B", value: 2), id: "2")

        try await sut.deleteAll(CodableStub.self)

        let results = try await sut.fetchAll(CodableStub.self)
        XCTAssertTrue(results.isEmpty)
    }

    func test_deleteAll_doesNotAffectOtherTypes() async throws {
        try await sut.save(CodableStub(name: "A", value: 1), id: "1")
        try await sut.save(AnotherCodableStub(label: "X"), id: "1")

        try await sut.deleteAll(CodableStub.self)

        let remaining = try await sut.fetchAll(AnotherCodableStub.self)
        XCTAssertEqual(remaining.count, 1)
    }
}

// MARK: - Test Helpers

private struct CodableStub: Codable, Equatable {
    let name: String
    let value: Int
}

private struct AnotherCodableStub: Codable, Equatable {
    let label: String
}
