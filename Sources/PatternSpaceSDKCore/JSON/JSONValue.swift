// Sources/PatternSpaceSDKCore/JSON/JSONValue.swift
import Foundation

public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
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

    public var object: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    public var array:  [JSONValue]?          { if case .array(let a)  = self { return a }; return nil }
    public var string: String?               { if case .string(let s) = self { return s }; return nil }
    public var bool:   Bool?                 { if case .bool(let b)   = self { return b }; return nil }
    public var int:    Int?                  { if case .int(let i)    = self { return i }; return nil }
    public var number: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i):    return Double(i)
        default:             return nil
        }
    }
}
