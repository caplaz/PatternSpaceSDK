import Foundation
import Testing
import PatternSpaceSDKCore

@Suite struct SignalSnapshotSchemasTests {
    @Test func minorSDKReleaseRetainsProtocolVersion() {
        #expect(PatternSpaceProtocolMetadata.sdkVersion == "1.1.0")
        #expect(PatternSpaceProtocolMetadata.protocolVersion == "1.3")
    }

    @Test func forwardTokensAndUnknownFieldsRoundTrip() throws {
        let token = try JSONDecoder().decode(SignalToken.self, from: Data(#""futureToken""#.utf8))
        #expect(token.rawValue == "futureToken")
        #expect(String(decoding: try JSONEncoder().encode(token), as: UTF8.self) == #""futureToken""#)
    }

    @Test func nonFiniteFieldsAreExplicitlyUnavailable() throws {
        let field = SignalFieldEvidence(name: "headroom", provenance: .appReported, number: .infinity)
        #expect(field.number == nil)
        #expect(field.reason == .nonFinite)
        _ = try JSONEncoder().encode(field)
    }

    @Test func evidenceBoundsRectanglesAndExcludesGuard() throws {
        let rectangles = (0..<65).map { SignalSampleEvidence(role: .rectangle, ordinal: $0) }
        let evidence = SignalSnapshotEvidence(identity: .init(diagnosticsEpoch: "epoch", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current,
            source: .init(status: .available, samples: rectangles))
        #expect(evidence.source.samples.count == 64)
        #expect(evidence.source.totalSampleCount == 65)
        #expect(evidence.source.omittedSampleCount == 1)
        let authorization = SignalProbeAuthorization(expectedContextGuard: "secret-guard", context:
            .init(diagnosticsEpoch: "epoch", targetRevision: 1, configurationRevision: 2, ownershipRevision: 3))
        let response = SignalSnapshotResponse(evidence: evidence, probeAuthorization: authorization)
        #expect(String(decoding: try JSONEncoder().encode(response), as: UTF8.self).contains("secret-guard"))
        #expect(!String(decoding: try JSONEncoder().encode(response.evidence), as: UTF8.self).contains("secret-guard"))
    }

    @Test func payloadLimitAndUnsupportedSchemaFailSafely() throws {
        let evidence = SignalSnapshotEvidence(identity: .init(diagnosticsEpoch: String(repeating: "x", count: 270_000), revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current)
        #expect(throws: SignalSnapshotValidationError.self) { try SignalSnapshotResponse(evidence: evidence).validatedData() }
        let future = SignalSnapshotEvidence(schemaVersion: 2, identity: .init(diagnosticsEpoch: "e", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current)
        #expect(!future.isSupportedSchema)
    }

    @Test func optionalDetailCanBeOmittedToFitLimit() throws {
        let fields = [SignalFieldEvidence(name: "profile", provenance: .appReported, text: String(repeating: "p", count: 270_000))]
        let evidence = SignalSnapshotEvidence(identity: .init(diagnosticsEpoch: "e", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current,
            appMapping: .init(status: .available, fields: fields))
        let response = try SignalSnapshotResponse.decodeValidated(SignalSnapshotResponse(evidence: evidence).validatedData())
        #expect(response.evidence.appMapping.fields.isEmpty)
        #expect(response.evidence.omissions.contains(.payloadLimit))
    }

    @Test func oldCapabilitiesDecodeWithAbsentNewFlags() throws {
        let json = #"{"events":true,"displayInventory":true,"peakWhiteControl":true,"outputColorPresets":true,"measurementRange":true,"catalogPatterns":true,"customICCBuilder":false,"httpBridge":false}"#
        let features = try JSONDecoder().decode(CapabilityFeatures.self, from: Data(json.utf8))
        #expect(features.signalSnapshot == nil)
        #expect(features.signalProbe == nil)
    }
    @Test func decodedMalformedCountsAndHistoricalAuthorizationAreRejected() throws {
        let base = SignalSnapshotResponse(evidence: .init(identity: .init(diagnosticsEpoch: "e", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current))
        var object = try JSONDecoder().decode(JSONValue.self, from: base.validatedData()).object!
        var evidence = object["evidence"]!.object!
        var source = evidence["source"]!.object!
        let sample = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(SignalSampleEvidence(role: .rectangle, ordinal: 0)))
        source["samples"] = .array(Array(repeating: sample, count: 65))
        source["totalSampleCount"] = .int(65)
        evidence["source"] = .object(source); object["evidence"] = .object(evidence)
        #expect(throws: SignalSnapshotValidationError.self) {
            try SignalSnapshotResponse.decodeValidated(JSONEncoder().encode(JSONValue.object(object)))
        }
        let historical = SignalSnapshotResponse(evidence: .init(identity: .init(diagnosticsEpoch: "e", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .historical),
            probeAuthorization: .init(expectedContextGuard: "guard", context: .init(diagnosticsEpoch: "e",
                targetRevision: 0, configurationRevision: 0, ownershipRevision: 0)))
        #expect(throws: SignalSnapshotValidationError.self) { try historical.validatedData() }
    }

    @Test func unknownFieldsDoNotBreakSchemaOneAndProbeWireIsFlat() throws {
        let base = SignalSnapshotResponse(evidence: .init(identity: .init(diagnosticsEpoch: "e", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current))
        var object = try JSONDecoder().decode(JSONValue.self, from: base.validatedData()).object!
        object["futureEnvelopeField"] = .string("ignored")
        let decoded = try SignalSnapshotResponse.decodeValidated(JSONEncoder().encode(JSONValue.object(object)))
        #expect(decoded == base)
        let patch = PatchParams(background: .init(r: 0, g: 0, b: 0), rectangles: [], bitDepth: .ten)
        let probe = SignalProbeParams(patch: patch, expectedContextGuard: "guard")
        let probeData = try JSONEncoder().encode(probe)
        let wire = try JSONDecoder().decode(JSONValue.self, from: probeData).object!
        #expect(wire["patch"] == nil)
        #expect(wire["bitDepth"] == .int(10))
        #expect(try JSONDecoder().decode(SignalProbeParams.self, from: probeData) == probe)
    }

    @Test func oversizedDetailMarksAffectedStageOmitted() throws {
        let base = SignalSnapshotResponse(evidence: .init(identity: .init(diagnosticsEpoch: "e", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current,
            source: .init(status: .available, fields: [.init(name: "detail", provenance: .received,
                text: String(repeating: "x", count: 270_000))])))
        let response = try SignalSnapshotResponse.decodeValidated(base.validatedData())
        #expect(response.evidence.source.reason == .payloadLimit)
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func invalidCaptureInitializerIsRejected(_ timestamp: Double) throws {
        for interval in [SignalCaptureInterval(startedAt: timestamp, completedAt: 2),
                         SignalCaptureInterval(startedAt: 1, completedAt: timestamp)] {
            let response = SignalSnapshotResponse(evidence: .init(identity: .init(diagnosticsEpoch: "e", revision: 1),
                capture: interval, freshness: .current))
            #expect(throws: SignalSnapshotValidationError.invalidEvidence) { try response.validate() }
        }
    }

    @Test func unsupportedSchemaCannotCarryAuthorizationOrDecodeAsUsableEvidence() throws {
        let response = SignalSnapshotResponse(evidence: .init(schemaVersion: 2,
            identity: .init(diagnosticsEpoch: "e", revision: 1), capture: .init(startedAt: 1, completedAt: 2), freshness: .current),
            probeAuthorization: .init(expectedContextGuard: "guard", context: .init(diagnosticsEpoch: "e",
                targetRevision: 0, configurationRevision: 0, ownershipRevision: 0)))
        #expect(throws: SignalSnapshotValidationError.unsupportedSchema(2)) { try response.validate() }
        #expect(throws: SignalSnapshotValidationError.unsupportedSchema(2)) {
            try SignalSnapshotResponse.decodeValidated(JSONEncoder().encode(response))
        }
    }

    @Test func incompatibleFutureShapeReportsUnsupportedBeforeFieldDecoding() throws {
        let data = Data(#"{"evidence":{"schemaVersion":9,"newShape":true},"probeAuthorization":{"unsafeFutureField":true}}"#.utf8)
        #expect(throws: SignalSnapshotValidationError.unsupportedSchema(9)) {
            try SignalSnapshotResponse.decodeValidated(data)
        }
    }

}
