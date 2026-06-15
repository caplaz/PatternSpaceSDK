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

    /// Requested display identifier does not exist.
    case displayNotFound = -32007

    /// Requested Peak White value is outside the display's accepted range.
    case peakWhiteOutOfRange = -32008

    /// Client is authenticated but not authorized for this operation.
    case notAuthorized = -32009

    /// Requested color-management mode is not supported on this platform or display.
    case colorManagementModeUnsupported = -32010

    /// Requested display does not match the host-global selected output display.
    case displaySelectionMismatch = -32011

    /// Requested output color preset is not supported on this platform or display.
    case outputColorPresetUnsupported = -32012

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
        case .displayNotFound: return "Display not found"
        case .peakWhiteOutOfRange: return "Peak White out of range"
        case .notAuthorized: return "Not authorized"
        case .colorManagementModeUnsupported: return "Color management mode unsupported"
        case .displaySelectionMismatch: return "Display selection mismatch"
        case .outputColorPresetUnsupported: return "Output color preset unsupported"
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
