//
//  SendableValue.swift
//  Thea
//
//  Shared Sendable-compatible value wrapper for Swift 6 strict concurrency
//

import Foundation

// MARK: - SendableValue

/// A Sendable-compatible wrapper for common primitive values.
/// This enum-based approach avoids `any Sendable` existential type issues
/// that arise in Swift 6's strict concurrency mode.
public enum SendableValue: Codable, Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case uuid(UUID)
    case url(URL)
    case array([SendableValue])
    case dictionary([String: SendableValue])
    case null

    // MARK: - Value Access

    /// The underlying value as Any
    public var value: Any {
        switch self {
        case let .string(v): v
        case let .int(v): v
        case let .double(v): v
        case let .bool(v): v
        case let .date(v): v
        case let .data(v): v
        case let .uuid(v): v
        case let .url(v): v
        case let .array(v): v.map(\.value)
        case let .dictionary(v): v.mapValues { $0.value }
        case .null: NSNull()
        }
    }

    /// String value or nil
    public var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }

    /// Int value or nil
    public var intValue: Int? {
        if case let .int(v) = self { return v }
        return nil
    }

    /// Double value or nil
    public var doubleValue: Double? {
        if case let .double(v) = self { return v }
        return nil
    }

    /// Bool value or nil
    public var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    /// Date value or nil
    public var dateValue: Date? {
        if case let .date(v) = self { return v }
        return nil
    }

    // MARK: - Initialization

    /// Initialize from any value, converting to appropriate case
    public init(_ value: Any) {
        switch value {
        case let str as String:
            self = .string(str)
        case let num as Int:
            self = .int(num)
        case let num as Double:
            self = .double(num)
        case let bool as Bool:
            self = .bool(bool)
        case let date as Date:
            self = .date(date)
        case let data as Data:
            self = .data(data)
        case let uuid as UUID:
            self = .uuid(uuid)
        case let url as URL:
            self = .url(url)
        case let array as [Any]:
            self = .array(array.map { SendableValue($0) })
        case let dict as [String: Any]:
            self = .dictionary(dict.mapValues { SendableValue($0) })
        case is NSNull:
            self = .null
        default:
            self = .string(String(describing: value))
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: Decoder) throws {
        // Attempt single-value decoding for simple JSON compatibility.
        // Each type is tried in order; the first successful decode wins.
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        do { self = .int(try container.decode(Int.self)); return } catch {}
        do { self = .double(try container.decode(Double.self)); return } catch {}
        do { self = .string(try container.decode(String.self)); return } catch {}
        do { self = .bool(try container.decode(Bool.self)); return } catch {}
        do { self = .date(try container.decode(Date.self)); return } catch {}
        do { self = .array(try container.decode([SendableValue].self)); return } catch {}
        do { self = .dictionary(try container.decode([String: SendableValue].self)); return } catch {}
        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(v):
            try container.encode(v)
        case let .int(v):
            try container.encode(v)
        case let .double(v):
            try container.encode(v)
        case let .bool(v):
            try container.encode(v)
        case let .date(v):
            try container.encode(v)
        case let .data(v):
            try container.encode(v.base64EncodedString())
        case let .uuid(v):
            try container.encode(v.uuidString)
        case let .url(v):
            try container.encode(v.absoluteString)
        case let .array(v):
            try container.encode(v)
        case let .dictionary(v):
            try container.encode(v)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - ExpressibleBy Protocols

extension SendableValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SendableValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension SendableValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension SendableValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension SendableValue: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        self = .null
    }
}

extension SendableValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SendableValue...) {
        self = .array(elements)
    }
}

extension SendableValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SendableValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Dictionary Conversion Utilities

public extension [String: SendableValue] {
    /// Convert from [String: Any] dictionary
    init(fromAny dict: [String: Any]) {
        self = dict.mapValues { SendableValue($0) }
    }

    // periphery:ignore - Reserved: toAnyDict() instance method reserved for future feature activation
    /// Convert to [String: Any] dictionary
    func toAnyDict() -> [String: Any] {
        mapValues { $0.value }
    }
}

public extension [AnyHashable: Any] {
    /// Convert to SendableValue dictionary (filtering non-string keys)
    func toSendableDict() -> [String: SendableValue] {
        var result: [String: SendableValue] = [:]
        for (key, value) in self {
            if let stringKey = key as? String {
                result[stringKey] = SendableValue(value)
            }
        }
        return result
    }
}
