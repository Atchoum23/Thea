@testable import TheaCore
import XCTest

final class SendableValueTests: XCTestCase {
    // MARK: - Case Construction

    func testStringCase() {
        let value = SendableValue.string("hello")
        XCTAssertEqual(value.stringValue, "hello")
        XCTAssertNil(value.intValue)
        XCTAssertNil(value.doubleValue)
        XCTAssertNil(value.boolValue)
        XCTAssertNil(value.dateValue)
    }

    func testIntCase() {
        let value = SendableValue.int(42)
        XCTAssertEqual(value.intValue, 42)
        XCTAssertNil(value.stringValue)
    }

    func testDoubleCase() {
        let value = SendableValue.double(3.14)
        XCTAssertEqual(value.doubleValue, 3.14)
        XCTAssertNil(value.intValue)
    }

    func testBoolCase() {
        let value = SendableValue.bool(true)
        XCTAssertEqual(value.boolValue, true)
        XCTAssertNil(value.stringValue)
    }

    func testDateCase() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let value = SendableValue.date(date)
        XCTAssertEqual(value.dateValue, date)
    }

    func testNullCase() {
        let value = SendableValue.null
        XCTAssertNil(value.stringValue)
        XCTAssertNil(value.intValue)
        XCTAssertNil(value.doubleValue)
        XCTAssertNil(value.boolValue)
        XCTAssertNil(value.dateValue)
    }

    // MARK: - Any Value Access

    func testStringAnyValue() {
        let value = SendableValue.string("test")
        XCTAssertEqual(value.value as? String, "test")
    }

    func testIntAnyValue() {
        let value = SendableValue.int(99)
        XCTAssertEqual(value.value as? Int, 99)
    }

    func testNullAnyValue() {
        let value = SendableValue.null
        XCTAssertTrue(value.value is NSNull)
    }

    func testArrayAnyValue() {
        let value = SendableValue.array([.string("a"), .int(1)])
        let arr = value.value as? [Any]
        XCTAssertEqual(arr?.count, 2)
        XCTAssertEqual(arr?.first as? String, "a")
        XCTAssertEqual(arr?.last as? Int, 1)
    }

    func testDictionaryAnyValue() {
        let value = SendableValue.dictionary(["key": .string("val")])
        let dict = value.value as? [String: Any]
        XCTAssertEqual(dict?["key"] as? String, "val")
    }

    // MARK: - Init from Any

    func testInitFromString() {
        let value = SendableValue("hello" as Any)
        XCTAssertEqual(value.stringValue, "hello")
    }

    func testInitFromInt() {
        let value = SendableValue(42 as Any)
        XCTAssertEqual(value.intValue, 42)
    }

    func testInitFromDouble() {
        let value = SendableValue(2.5 as Any)
        XCTAssertEqual(value.doubleValue, 2.5)
    }

    func testInitFromBool() {
        let value = SendableValue(true as Any)
        XCTAssertEqual(value.boolValue, true)
    }

    func testInitFromDate() {
        let date = Date()
        let value = SendableValue(date as Any)
        XCTAssertEqual(value.dateValue, date)
    }

    func testInitFromData() {
        let data = Data([0x01, 0x02, 0x03])
        let value = SendableValue(data as Any)
        if case let .data(d) = value {
            XCTAssertEqual(d, data)
        } else {
            XCTFail("Expected .data case")
        }
    }

    func testInitFromUUID() {
        let uuid = UUID()
        let value = SendableValue(uuid as Any)
        if case let .uuid(u) = value {
            XCTAssertEqual(u, uuid)
        } else {
            XCTFail("Expected .uuid case")
        }
    }

    func testInitFromURL() {
        let url = URL(string: "https://example.com")!
        let value = SendableValue(url as Any)
        if case let .url(u) = value {
            XCTAssertEqual(u, url)
        } else {
            XCTFail("Expected .url case")
        }
    }

    func testInitFromNSNull() {
        let value = SendableValue(NSNull() as Any)
        XCTAssertEqual(value, .null)
    }

    func testInitFromUnknownType() {
        // Unknown types fallback to .string(String(describing:))
        struct CustomType {}
        let value = SendableValue(CustomType() as Any)
        XCTAssertNotNil(value.stringValue)
    }

    func testInitFromArray() {
        let value = SendableValue(["a", "b"] as Any)
        if case let .array(arr) = value {
            XCTAssertEqual(arr.count, 2)
            XCTAssertEqual(arr[0].stringValue, "a")
        } else {
            XCTFail("Expected .array case")
        }
    }

    func testInitFromDictionary() {
        let value = SendableValue(["key": 42] as Any)
        if case let .dictionary(dict) = value {
            XCTAssertEqual(dict["key"]?.intValue, 42)
        } else {
            XCTFail("Expected .dictionary case")
        }
    }

    // MARK: - Codable Round-Trip

    func testCodableString() throws {
        let original = SendableValue.string("codable")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        XCTAssertEqual(decoded.stringValue, "codable")
    }

    func testCodableInt() throws {
        let original = SendableValue.int(7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        XCTAssertEqual(decoded.intValue, 7)
    }

    func testCodableDouble() throws {
        let original = SendableValue.double(1.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        XCTAssertEqual(decoded.doubleValue, 1.5)
    }

    func testCodableBool() throws {
        let original = SendableValue.bool(false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        XCTAssertEqual(decoded.boolValue, false)
    }

    func testCodableNull() throws {
        let original = SendableValue.null
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        XCTAssertEqual(decoded, .null)
    }

    func testCodableArray() throws {
        let original = SendableValue.array([.string("x"), .int(1)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        if case let .array(arr) = decoded {
            XCTAssertEqual(arr.count, 2)
        } else {
            XCTFail("Expected .array case after decoding")
        }
    }

    func testCodableDictionary() throws {
        let original = SendableValue.dictionary(["a": .int(1), "b": .string("two")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: data)
        if case let .dictionary(dict) = decoded {
            XCTAssertEqual(dict.count, 2)
        } else {
            XCTFail("Expected .dictionary case after decoding")
        }
    }

    // MARK: - ExpressibleBy Literals

    func testStringLiteral() {
        let value: SendableValue = "hello"
        XCTAssertEqual(value.stringValue, "hello")
    }

    func testIntegerLiteral() {
        let value: SendableValue = 42
        XCTAssertEqual(value.intValue, 42)
    }

    func testFloatLiteral() {
        let value: SendableValue = 3.14
        XCTAssertEqual(value.doubleValue, 3.14)
    }

    func testBooleanLiteral() {
        let value: SendableValue = true
        XCTAssertEqual(value.boolValue, true)
    }

    func testNilLiteral() {
        let value: SendableValue = nil
        XCTAssertEqual(value, .null)
    }

    func testArrayLiteral() {
        let value: SendableValue = ["a", 1, true]
        if case let .array(arr) = value {
            XCTAssertEqual(arr.count, 3)
            XCTAssertEqual(arr[0].stringValue, "a")
            XCTAssertEqual(arr[1].intValue, 1)
            XCTAssertEqual(arr[2].boolValue, true)
        } else {
            XCTFail("Expected .array case")
        }
    }

    func testDictionaryLiteral() {
        let value: SendableValue = ["name": "test", "count": 5]
        if case let .dictionary(dict) = value {
            XCTAssertEqual(dict["name"]?.stringValue, "test")
            XCTAssertEqual(dict["count"]?.intValue, 5)
        } else {
            XCTFail("Expected .dictionary case")
        }
    }

    // MARK: - Equatable & Hashable

    func testEquality() {
        XCTAssertEqual(SendableValue.string("a"), SendableValue.string("a"))
        XCTAssertNotEqual(SendableValue.string("a"), SendableValue.string("b"))
        XCTAssertNotEqual(SendableValue.string("42"), SendableValue.int(42))
        XCTAssertEqual(SendableValue.null, SendableValue.null)
    }

    func testHashable() {
        var set: Set<SendableValue> = []
        set.insert(.string("a"))
        set.insert(.string("a"))
        set.insert(.int(1))
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Dictionary Conversion Utilities

    func testFromAnyDict() {
        let anyDict: [String: Any] = ["name": "Thea", "version": 2]
        let sendable = [String: SendableValue](fromAny: anyDict)
        XCTAssertEqual(sendable["name"]?.stringValue, "Thea")
        XCTAssertEqual(sendable["version"]?.intValue, 2)
    }

    func testToAnyDict() {
        let sendable: [String: SendableValue] = ["x": .string("y"), "n": .int(3)]
        let anyDict = sendable.toAnyDict()
        XCTAssertEqual(anyDict["x"] as? String, "y")
        XCTAssertEqual(anyDict["n"] as? Int, 3)
    }

    func testAnyHashableDictConversion() {
        let raw: [AnyHashable: Any] = ["key1": "val1", "key2": 42, 999: "non-string-key"]
        let sendable = raw.toSendableDict()
        XCTAssertEqual(sendable["key1"]?.stringValue, "val1")
        XCTAssertEqual(sendable["key2"]?.intValue, 42)
        // Non-string key should be filtered out
        XCTAssertEqual(sendable.count, 2)
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let value = SendableValue.string("")
        XCTAssertEqual(value.stringValue, "")
    }

    func testZeroInt() {
        let value = SendableValue.int(0)
        XCTAssertEqual(value.intValue, 0)
    }

    func testNegativeInt() {
        let value = SendableValue.int(-100)
        XCTAssertEqual(value.intValue, -100)
    }

    func testEmptyArray() {
        let value = SendableValue.array([])
        if case let .array(arr) = value {
            XCTAssertTrue(arr.isEmpty)
        } else {
            XCTFail("Expected .array case")
        }
    }

    func testEmptyDictionary() {
        let value = SendableValue.dictionary([:])
        if case let .dictionary(dict) = value {
            XCTAssertTrue(dict.isEmpty)
        } else {
            XCTFail("Expected .dictionary case")
        }
    }

    func testNestedArrays() {
        let inner = SendableValue.array([.int(1), .int(2)])
        let outer = SendableValue.array([inner, .string("end")])
        if case let .array(arr) = outer {
            XCTAssertEqual(arr.count, 2)
            if case let .array(innerArr) = arr[0] {
                XCTAssertEqual(innerArr.count, 2)
            } else {
                XCTFail("Expected nested .array")
            }
        } else {
            XCTFail("Expected .array case")
        }
    }

    func testNestedDictionaries() {
        let inner = SendableValue.dictionary(["nested": .bool(true)])
        let outer = SendableValue.dictionary(["child": inner])
        if case let .dictionary(dict) = outer,
           case let .dictionary(innerDict) = dict["child"]
        {
            XCTAssertEqual(innerDict["nested"]?.boolValue, true)
        } else {
            XCTFail("Expected nested .dictionary")
        }
    }

    // MARK: - Data & UUID encoding

    func testDataBase64Encoding() throws {
        let original = SendableValue.data(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        let jsonData = try JSONEncoder().encode(original)
        // Data encodes as base64 string, so it decodes as .string
        let decoded = try JSONDecoder().decode(SendableValue.self, from: jsonData)
        // The decoded value will be a string (base64), not .data
        XCTAssertNotNil(decoded.stringValue)
    }

    func testUUIDEncoding() throws {
        let uuid = UUID()
        let original = SendableValue.uuid(uuid)
        let jsonData = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: jsonData)
        // UUID encodes as string
        XCTAssertEqual(decoded.stringValue, uuid.uuidString)
    }

    func testURLEncoding() throws {
        let url = URL(string: "https://thea.app/test")!
        let original = SendableValue.url(url)
        let jsonData = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SendableValue.self, from: jsonData)
        XCTAssertEqual(decoded.stringValue, url.absoluteString)
    }
}
