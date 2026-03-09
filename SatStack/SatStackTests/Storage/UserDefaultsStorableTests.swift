import XCTest
@testable import SatStack

final class UserDefaultsStorableTests: XCTestCase {

    // MARK: - SUT

    private var sut: UserDefaultsStorable!
    private var defaults: UserDefaults!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UserDefaultsStorableTests")!
        defaults.removePersistentDomain(forName: "UserDefaultsStorableTests")
        sut = UserDefaultsStorable(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "UserDefaultsStorableTests")
        defaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - String

    func test_string_returnsNil_whenKeyDoesNotExist() {
        XCTAssertNil(sut.string(forKey: "missing"))
    }

    func test_string_returnsStoredValue() {
        sut.set("hello", forKey: "key")
        XCTAssertEqual(sut.string(forKey: "key"), "hello")
    }

    // MARK: - Int

    func test_int_returnsNil_whenKeyDoesNotExist() {
        XCTAssertNil(sut.int(forKey: "missing"))
    }

    func test_int_returnsStoredValue() {
        sut.set(42, forKey: "key")
        XCTAssertEqual(sut.int(forKey: "key"), 42)
    }

    func test_int_returnsZero_whenStoredValueIsZero() {
        sut.set(0, forKey: "key")
        XCTAssertEqual(sut.int(forKey: "key"), 0)
    }

    // MARK: - Double

    func test_double_returnsNil_whenKeyDoesNotExist() {
        XCTAssertNil(sut.double(forKey: "missing"))
    }

    func test_double_returnsStoredValue() {
        sut.set(3.14, forKey: "key")
        let result = sut.double(forKey: "key")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 3.14, accuracy: 0.001)
    }

    // MARK: - Bool

    func test_bool_returnsNil_whenKeyDoesNotExist() {
        XCTAssertNil(sut.bool(forKey: "missing"))
    }

    func test_bool_returnsTrue_whenStoredTrue() {
        sut.set(true, forKey: "key")
        XCTAssertEqual(sut.bool(forKey: "key"), true)
    }

    func test_bool_returnsFalse_whenStoredFalse() {
        sut.set(false, forKey: "key")
        XCTAssertEqual(sut.bool(forKey: "key"), false)
    }

    // MARK: - Data

    func test_data_returnsNil_whenKeyDoesNotExist() {
        XCTAssertNil(sut.data(forKey: "missing"))
    }

    func test_data_returnsStoredValue() {
        let data = Data("bytes".utf8)
        sut.set(data, forKey: "key")
        XCTAssertEqual(sut.data(forKey: "key"), data)
    }

    // MARK: - Codable (default implementation)

    func test_setObject_and_object_roundTripsCodable() {
        let model = CodableStub(name: "Bitcoin", value: 21_000_000)
        sut.setObject(model, forKey: "key")

        let retrieved: CodableStub? = sut.object(forKey: "key")
        XCTAssertEqual(retrieved, model)
    }

    func test_object_returnsNil_whenKeyDoesNotExist() {
        let result: CodableStub? = sut.object(forKey: "missing")
        XCTAssertNil(result)
    }

    func test_object_returnsNil_whenDataIsCorrupted() {
        sut.set(Data("not valid json".utf8), forKey: "key")
        let result: CodableStub? = sut.object(forKey: "key")
        XCTAssertNil(result)
    }

    // MARK: - Remove

    func test_removeObject_clearsStoredValue() {
        sut.set("hello", forKey: "key")
        sut.removeObject(forKey: "key")
        XCTAssertNil(sut.string(forKey: "key"))
    }

    // MARK: - Set nil

    func test_set_nil_removesValue() {
        sut.set("hello", forKey: "key")
        sut.set(nil, forKey: "key")
        XCTAssertNil(sut.string(forKey: "key"))
    }
}

// MARK: - Test Helpers

private struct CodableStub: Codable, Equatable {
    let name: String
    let value: Int
}
