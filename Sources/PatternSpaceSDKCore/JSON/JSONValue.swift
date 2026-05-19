// Sources/PatternSpaceSDKCore/JSON/JSONValue.swift
import Foundation

/// A type-safe representation of arbitrary JSON values.
///
/// The dispatcher uses `JSONValue` when it needs to validate request envelopes
/// before decoding method-specific parameter structures.
public enum JSONValue: Codable, Sendable, Equatable {
    /// The JSON `null` value.
    case null

    /// A JSON boolean.
    case bool(Bool)

    /// A JSON integer number.
    case int(Int)

    /// A JSON floating-point number.
    case double(Double)

    /// A JSON string.
    case string(String)

    /// A JSON array.
    case array([JSONValue])

    /// A JSON object.
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                           { self = .null;                        return }
        if let v = try? c.decode(Bool.self)        { self = .bool(v);                     return }
        if let v = try? c.decode(Int.self)         { self = .int(v);                      return }
        if let v = try? c.decode(Double.self)      { self = .double(v);                   return }
        if let v = try? c.decode(String.self)      { self = .string(v);                   return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v);                    return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v);           return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                debugDescription: "Unrecognised JSON value"))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:          try c.encodeNil()
        case .bool(let v):   try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    /// Returns the object payload when this value is an object.
    public var object: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }

    /// Returns the array payload when this value is an array.
    public var array:  [JSONValue]?          { if case .array(let a)  = self { return a }; return nil }

    /// Returns the string payload when this value is a string.
    public var string: String?               { if case .string(let s) = self { return s }; return nil }

    /// Returns the boolean payload when this value is a boolean.
    public var bool:   Bool?                 { if case .bool(let b)   = self { return b }; return nil }

    /// Returns the integer payload when this value is an integer.
    public var int:    Int?                  { if case .int(let i)    = self { return i }; return nil }

    /// Returns either integer or floating-point JSON numbers as `Double`.
    public var number: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i):    return Double(i)
        default:             return nil
        }
    }
}
