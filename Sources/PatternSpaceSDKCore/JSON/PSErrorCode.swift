// Sources/PatternSpaceSDKCore/JSON/PSErrorCode.swift
import Foundation

/// PatternSpace JSON-RPC error codes.
public enum PSErrorCode: Int, Sendable {
    /// Standard JSON-RPC parse error.
    case parseError      = -32700

    /// Standard JSON-RPC invalid request error.
    case invalidRequest  = -32600

    /// Standard JSON-RPC method-not-found error.
    case methodNotFound  = -32601

    /// Standard JSON-RPC invalid-params error.
    case invalidParams   = -32602

    /// Standard JSON-RPC internal error.
    case internalError   = -32603

    /// Requested pattern identifier does not exist.
    case patternNotFound = -32002

    /// Host app failed to display the requested pattern.
    case displayError    = -32003

    /// Requested bit depth is not supported.
    case invalidBitDepth = -32004

    /// JSON source is connected but not the active PatternSpace source.
    case sourceNotActive = -32005

    /// Client sent too many requests in the current rate-limit window.
    case rateLimitExceeded = -32006

    /// Default message paired with this error code.
    public var defaultMessage: String {
        switch self {
        case .parseError:       return "Parse error"
        case .invalidRequest:   return "Invalid request"
        case .methodNotFound:   return "Method not found"
        case .invalidParams:    return "Invalid params"
        case .internalError:    return "Internal error"
        case .patternNotFound:  return "Pattern not found"
        case .displayError:     return "Display error"
        case .invalidBitDepth:  return "Invalid bit depth"
        case .sourceNotActive:  return "Source not active"
        case .rateLimitExceeded: return "Rate limit exceeded"
        }
    }
}

/// Error thrown by dispatch handlers to build structured JSON-RPC failures.
public struct PSDispatchError: Error, Sendable {
    /// PatternSpace error code.
    public let code: PSErrorCode

    /// Human-readable error message.
    public let message: String

    /// Optional structured error details.
    public let data: JSONValue?

    /// Creates a dispatch error.
    public init(_ code: PSErrorCode, message: String? = nil, data: JSONValue? = nil) {
        self.code = code
        self.message = message ?? code.defaultMessage
        self.data = data
    }
}
