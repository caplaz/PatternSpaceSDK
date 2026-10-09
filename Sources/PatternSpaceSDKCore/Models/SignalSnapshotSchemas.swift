import Foundation

public struct SignalSnapshotIdentity: Codable, Sendable, Equatable {
    public let diagnosticsEpoch: String
    public let revision: UInt64
    public let targetLifetime: String?
    public let targetRevision: UInt64
    public let configurationRevision: UInt64
    public let ownershipRevision: UInt64
    public let sourceLifetime: String?
    public let acceptedContentID: String?
    public let acceptedSequence: UInt64?
    public let publishedContentID: String?
    public let publishedSequence: UInt64?
    public init(diagnosticsEpoch: String, revision: UInt64, targetLifetime: String? = nil,
                targetRevision: UInt64 = 0, configurationRevision: UInt64 = 0, ownershipRevision: UInt64 = 0,
                sourceLifetime: String? = nil, acceptedContentID: String? = nil, acceptedSequence: UInt64? = nil,
                publishedContentID: String? = nil, publishedSequence: UInt64? = nil) {
        self.diagnosticsEpoch = diagnosticsEpoch; self.revision = revision; self.targetLifetime = targetLifetime
        self.targetRevision = targetRevision; self.configurationRevision = configurationRevision
        self.ownershipRevision = ownershipRevision; self.sourceLifetime = sourceLifetime
        self.acceptedContentID = acceptedContentID; self.acceptedSequence = acceptedSequence
        self.publishedContentID = publishedContentID; self.publishedSequence = publishedSequence
    }
}

/// Immutable schema-1 evidence. This type has no authorization or packed frame buffer field.
public struct SignalSnapshotEvidence: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let identity: SignalSnapshotIdentity
    public let capture: SignalCaptureInterval
    public let freshness: SignalToken
    public let source: SignalStageEvidence
    public let appMapping: SignalStageEvidence
    public let sdiFrame: SignalStageEvidence
    public let physicalSignal: SignalStageEvidence
    public let omissions: [SignalToken]
    public var isSupportedSchema: Bool { schemaVersion == 1 }
    public init(schemaVersion: Int = 1, identity: SignalSnapshotIdentity, capture: SignalCaptureInterval,
                freshness: SignalToken, source: SignalStageEvidence = .init(), appMapping: SignalStageEvidence = .init(),
                sdiFrame: SignalStageEvidence = .init(), physicalSignal: SignalStageEvidence = .init(),
                omissions: [SignalToken] = []) {
        self.schemaVersion = schemaVersion; self.identity = identity; self.capture = capture; self.freshness = freshness
        self.source = source; self.appMapping = appMapping; self.sdiFrame = sdiFrame; self.physicalSignal = physicalSignal
        self.omissions = omissions
    }
    func omittingDetails() -> Self {
        Self(schemaVersion: schemaVersion, identity: identity, capture: capture, freshness: freshness,
             source: source.omittingDetails(), appMapping: appMapping.omittingDetails(),
             sdiFrame: sdiFrame.omittingDetails(), physicalSignal: physicalSignal.omittingDetails(),
             omissions: omissions.contains(.payloadLimit) ? omissions : omissions + [.payloadLimit])
    }
}

public enum SignalSnapshotValidationError: Error, Sendable, Equatable {
    case payloadTooLarge
    case tooManySamples
    case invalidEvidence
    case invalidAuthorization
    case unsupportedSchema(Int)
}

/// Connection-specific read response. Share/export only `evidence`, never this envelope.
public struct SignalSnapshotResponse: Codable, Sendable, Equatable {
    public static let maximumPayloadBytes = 256 * 1024
    public let evidence: SignalSnapshotEvidence
    public let probeAuthorization: SignalProbeAuthorization?
    public init(evidence: SignalSnapshotEvidence, probeAuthorization: SignalProbeAuthorization? = nil) {
        self.evidence = evidence; self.probeAuthorization = probeAuthorization
    }

    /// Encodes finite bounded evidence; oversized optional details become explicitly omitted.
    /// If authoritative identity alone exceeds the bound, encoding fails instead of truncating identity.
    public func validatedData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        if data.count <= Self.maximumPayloadBytes { return data }
        let reduced = Self(evidence: evidence.omittingDetails(), probeAuthorization: probeAuthorization)
        let bounded = try encoder.encode(reduced)
        guard bounded.count <= Self.maximumPayloadBytes else { throw SignalSnapshotValidationError.payloadTooLarge }
        return bounded
    }

    /// Checks the wire bound and schema before decoding any evidence or authorization.
    public static func decodeValidated(_ data: Data) throws -> Self {
        guard data.count <= maximumPayloadBytes else { throw SignalSnapshotValidationError.payloadTooLarge }
        struct Header: Decodable {
            struct Evidence: Decodable { let schemaVersion: Int }
            let evidence: Evidence
        }
        let schema = try JSONDecoder().decode(Header.self, from: data).evidence.schemaVersion
        guard schema == 1 else { throw SignalSnapshotValidationError.unsupportedSchema(schema) }
        let response = try JSONDecoder().decode(Self.self, from: data)
        try response.validate()
        return response
    }

    public func validate() throws {
        guard evidence.isSupportedSchema else {
            throw SignalSnapshotValidationError.unsupportedSchema(evidence.schemaVersion)
        }
        guard !evidence.identity.diagnosticsEpoch.isEmpty,
              evidence.capture.startedAt.isFinite, evidence.capture.completedAt.isFinite,
              evidence.capture.completedAt >= evidence.capture.startedAt else {
            throw SignalSnapshotValidationError.invalidEvidence
        }
        for stage in [evidence.source, evidence.appMapping, evidence.sdiFrame, evidence.physicalSignal] {
            guard stage.samples.count <= 64 else { throw SignalSnapshotValidationError.tooManySamples }
            guard stage.totalSampleCount >= stage.samples.count,
                  stage.omittedSampleCount == stage.totalSampleCount - stage.samples.count else {
                throw SignalSnapshotValidationError.invalidEvidence
            }
            try validateCapture(stage.capture)
            guard stage.submittedAt?.isFinite != false, stage.presentedAt?.isFinite != false else {
                throw SignalSnapshotValidationError.invalidEvidence
            }
            for field in stage.fields { try validateField(field) }
            for sample in stage.samples {
                guard sample.ordinal >= 0, sample.receivedValues?.isFinite != false,
                      sample.effectiveRendererInput?.isFinite != false else {
                    throw SignalSnapshotValidationError.invalidEvidence
                }
                if let geometry = sample.geometry {
                    guard [geometry.x, geometry.y, geometry.width, geometry.height].allSatisfy(\.isFinite) else {
                        throw SignalSnapshotValidationError.invalidEvidence
                    }
                }
                for field in sample.fields { try validateField(field) }
            }
        }
        if let auth = probeAuthorization {
            guard SignalProbeParams.isValidGuard(auth.expectedContextGuard),
                  auth.context.diagnosticsEpoch == evidence.identity.diagnosticsEpoch,
                  auth.context.targetLifetime == evidence.identity.targetLifetime,
                  auth.context.targetRevision == evidence.identity.targetRevision,
                  auth.context.configurationRevision == evidence.identity.configurationRevision,
                  auth.context.ownershipRevision == evidence.identity.ownershipRevision,
                  evidence.freshness == .current else { throw SignalSnapshotValidationError.invalidAuthorization }
        }
    }
    private func validateField(_ field: SignalFieldEvidence) throws {
        guard field.number?.isFinite != false else { throw SignalSnapshotValidationError.invalidEvidence }
        try validateCapture(field.capture)
    }
    private func validateCapture(_ interval: SignalCaptureInterval?) throws {
        if let interval {
            guard interval.startedAt.isFinite, interval.completedAt.isFinite,
                  interval.completedAt >= interval.startedAt else { throw SignalSnapshotValidationError.invalidEvidence }
        }
    }
}
