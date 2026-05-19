// Sources/PatternSpaceSDKCore/JSON/JSONRPCTypes.swift
import Foundation

// MARK: - ID

public enum JSONRPCId: Codable, Hashable, Sendable, Equatable {
    case string(String)
    case integer(Int)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "id must not be null"))
        }
        if let s = try? c.decode(String.self) { self = .string(s);  return }
        if let i = try? c.decode(Int.self)    { self = .integer(i); return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                debugDescription: "id must be string or integer"))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try c.encode(s)
        case .integer(let i): try c.encode(i)
        }
    }
}

// MARK: - Incoming request (server parses this)

public struct IncomingRequest: Decodable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId           // required; null rejected by JSONRPCId.init
    public let method: String
    public let params: JSONValue?
}

// MARK: - Outgoing responses (server sends these)

public struct JSONRPCSuccessResponse: Encodable, Sendable {
    public let jsonrpc = "2.0"
    public let id: JSONRPCId
    public let result: JSONValue

    public init(id: JSONRPCId, result: JSONValue) {
        self.id = id
        self.result = result
    }
}

public struct JSONRPCErrorPayload: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public struct JSONRPCErrorResponse: Encodable, Sendable {
    public let jsonrpc = "2.0"
    public let id: JSONRPCId
    public let error: JSONRPCErrorPayload

    public init(id: JSONRPCId, error: JSONRPCErrorPayload) {
        self.id = id
        self.error = error
    }
}

// Parse errors use null id per JSON-RPC 2.0 §5
public struct JSONRPCParseErrorResponse: Encodable, Sendable {
    public let jsonrpc = "2.0"
    public let id: JSONValue = .null
    public let error = JSONRPCErrorPayload(code: -32700, message: "Parse error")
}

// MARK: - Outgoing notifications (server → clients, no id)

public struct JSONRPCNotification<P: Encodable & Sendable>: Encodable, Sendable {
    public let jsonrpc = "2.0"
    public let method: String
    public let params: P

    public init(method: String, params: P) {
        self.method = method
        self.params = params
    }
}
