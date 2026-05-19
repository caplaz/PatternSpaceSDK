// Sources/PatternSpaceSDKCore/JSON/JSONRPCTypes.swift
import Foundation

// MARK: - ID

/// JSON-RPC request identifier.
///
/// PatternSpace accepts string and integer identifiers. Notifications are not
/// supported, so `null` identifiers are rejected by the server.
public enum JSONRPCId: Codable, Hashable, Sendable, Equatable {
    /// String request identifier.
    case string(String)

    /// Integer request identifier.
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

/// A JSON-RPC request after envelope validation.
public struct IncomingRequest: Decodable, Sendable {
    /// JSON-RPC version. Must be `"2.0"`.
    public let jsonrpc: String

    /// Request id. PatternSpace requires an id for every request.
    public let id: JSONRPCId           // required; null rejected by JSONRPCId.init

    /// Method name, such as `pattern.display`.
    public let method: String

    /// Optional method parameters.
    public let params: JSONValue?
}

// MARK: - Outgoing responses (server sends these)

/// JSON-RPC success response.
public struct JSONRPCSuccessResponse: Encodable, Sendable {
    /// JSON-RPC version.
    public let jsonrpc = "2.0"

    /// Identifier copied from the request.
    public let id: JSONRPCId

    /// Method result payload.
    public let result: JSONValue

    /// Creates a success response.
    public init(id: JSONRPCId, result: JSONValue) {
        self.id = id
        self.result = result
    }
}

/// JSON-RPC error object.
public struct JSONRPCErrorPayload: Codable, Sendable {
    /// Numeric JSON-RPC or PatternSpace error code.
    public let code: Int

    /// Human-readable error message.
    public let message: String

    /// Optional structured error details.
    public let data: JSONValue?

    /// Creates an error object.
    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// JSON-RPC error response with a recoverable request id.
public struct JSONRPCErrorResponse: Encodable, Sendable {
    /// JSON-RPC version.
    public let jsonrpc = "2.0"

    /// Identifier copied from the request.
    public let id: JSONRPCId

    /// Error payload.
    public let error: JSONRPCErrorPayload

    /// Creates an error response.
    public init(id: JSONRPCId, error: JSONRPCErrorPayload) {
        self.id = id
        self.error = error
    }
}

/// JSON-RPC parse error response.
///
/// Parse errors use a `null` id because the request identifier could not be
/// read from the malformed JSON payload.
public struct JSONRPCParseErrorResponse: Encodable, Sendable {
    /// JSON-RPC version.
    public let jsonrpc = "2.0"

    /// Parse errors use `null` ids per JSON-RPC 2.0.
    public let id: JSONValue = .null

    /// Standard parse error payload.
    public let error = JSONRPCErrorPayload(code: -32700, message: "Parse error")
}

// MARK: - Outgoing notifications (server → clients, no id)

/// JSON-RPC notification sent by the server to connected clients.
public struct JSONRPCNotification<P: Encodable & Sendable>: Encodable, Sendable {
    /// JSON-RPC version.
    public let jsonrpc = "2.0"

    /// Notification method name.
    public let method: String

    /// Notification payload.
    public let params: P

    /// Creates a server notification.
    public init(method: String, params: P) {
        self.method = method
        self.params = params
    }
}
