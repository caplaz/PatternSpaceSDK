import Foundation

/// Stable expected host context; diagnostics snapshot revision and patch sequence are deliberately absent.
public struct SignalProbeContext: Codable, Sendable, Equatable {
    public let diagnosticsEpoch: String
    public let targetLifetime: String?
    public let targetRevision: UInt64
    public let configurationRevision: UInt64
    public let ownershipRevision: UInt64
    public init(diagnosticsEpoch: String, targetLifetime: String? = nil, targetRevision: UInt64,
                configurationRevision: UInt64, ownershipRevision: UInt64) {
        self.diagnosticsEpoch = diagnosticsEpoch; self.targetLifetime = targetLifetime
        self.targetRevision = targetRevision; self.configurationRevision = configurationRevision
        self.ownershipRevision = ownershipRevision
    }
}

/// An opaque guard valid for one authenticated connection and exact host context.
public struct SignalProbeAuthorization: Codable, Sendable, Equatable {
    public let expectedContextGuard: String
    public let context: SignalProbeContext
    public init(expectedContextGuard: String, context: SignalProbeContext) {
        self.expectedContextGuard = expectedContextGuard; self.context = context
    }
}

/// The same patch wire shape as `displayPatch`, plus a required opaque context guard.
public struct SignalProbeParams: Codable, Sendable, Equatable {
    public let patch: PatchParams
    public let expectedContextGuard: String
    public init(patch: PatchParams, expectedContextGuard: String) {
        self.patch = patch; self.expectedContextGuard = expectedContextGuard
    }
    enum CodingKeys: String, CodingKey { case background, rectangles, bitDepth, expectedContextGuard }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        patch = PatchParams(background: try c.decode(PSColor.self, forKey: .background),
            rectangles: try c.decode([PatchRectangle].self, forKey: .rectangles),
            bitDepth: try c.decode(BitDepth.self, forKey: .bitDepth))
        expectedContextGuard = try c.decode(String.self, forKey: .expectedContextGuard)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(patch.background, forKey: .background)
        try c.encode(patch.rectangles, forKey: .rectangles)
        try c.encode(patch.bitDepth, forKey: .bitDepth)
        try c.encode(expectedContextGuard, forKey: .expectedContextGuard)
    }
    /// Guards are bounded printable ASCII with no whitespace; their contents have no SDK semantics.
    public static func isValidGuard(_ guardValue: String) -> Bool {
        !guardValue.isEmpty && guardValue.utf8.count <= 512 && guardValue.utf8.allSatisfy { (33...126).contains($0) }
    }
}
