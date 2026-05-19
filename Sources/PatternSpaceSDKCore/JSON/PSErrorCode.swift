// Sources/PatternSpaceSDKCore/JSON/PSErrorCode.swift
import Foundation

public enum PSErrorCode: Int, Sendable {
    case parseError      = -32700
    case invalidRequest  = -32600
    case methodNotFound  = -32601
    case invalidParams   = -32602
    case internalError   = -32603
    case patternNotFound = -32002
    case displayError    = -32003
    case invalidBitDepth = -32004
    case sourceNotActive = -32005
    case rateLimitExceeded = -32006

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

// Thrown by dispatch handlers; caught by JSONRPCDispatcher to build error responses
public struct PSDispatchError: Error, Sendable {
    public let code: PSErrorCode
    public let message: String
    public let data: JSONValue?

    public init(_ code: PSErrorCode, message: String? = nil, data: JSONValue? = nil) {
        self.code = code
        self.message = message ?? code.defaultMessage
        self.data = data
    }
}
