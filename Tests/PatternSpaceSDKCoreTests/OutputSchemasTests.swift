// Tests/PatternSpaceSDKCoreTests/OutputSchemasTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKCore

@Suite struct OutputSchemasTests {
    private let epoch = "6F9619FF-8B86-D011-B42D-00C04FC964FF"

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: JSONValue] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONDecoder().decode(JSONValue.self, from: data).object)
    }

    // MARK: - OutputStatus

    @Test func pendingBlankStatusRoundTrips() throws {
        let status = OutputStatus(
            owner: .jsonClient,
            ownerConnected: true,
            blankRequester: .local,
            blanked: nil,
            blankPending: true,
            failure: nil,
            idleBlankSeconds: 300,
            epoch: epoch,
            revision: 7
        )
        #expect(try roundTrip(status) == status)
    }

    @Test func activeBlankStatusRoundTrips() throws {
        let status = OutputStatus(
            owner: .calman,
            ownerConnected: false,
            blankRequester: .jsonClient,
            blanked: .remote,
            blankPending: false,
            failure: nil,
            idleBlankSeconds: nil,
            epoch: epoch,
            revision: 42
        )
        #expect(try roundTrip(status) == status)
    }

    @Test func failureStatusRoundTrips() throws {
        for failure in [PSOutputFailure.notPresented, .outputUnknown] {
            let status = OutputStatus(
                owner: .local,
                ownerConnected: false,
                blankRequester: nil,
                blanked: nil,
                blankPending: false,
                failure: failure,
                idleBlankSeconds: 60,
                epoch: epoch,
                revision: UInt64.max
            )
            #expect(try roundTrip(status) == status)
        }
    }

    @Test func statusEncodesWireNamesAndExplicitNulls() throws {
        let status = OutputStatus(
            owner: .pGenerator,
            ownerConnected: true,
            blankRequester: nil,
            blanked: nil,
            blankPending: false,
            failure: nil,
            idleBlankSeconds: nil,
            epoch: epoch,
            revision: 3
        )
        let object = try jsonObject(status)
        #expect(object["owner"] == .string("pGenerator"))
        #expect(object["ownerConnected"] == .bool(true))
        #expect(object["blankRequester"] == .null)
        #expect(object["blanked"] == .null)
        #expect(object["blankPending"] == .bool(false))
        #expect(object["failure"] == .null)
        #expect(object["idleBlankSeconds"] == .null)
        #expect(object["epoch"] == .string(epoch))
        #expect(object["revision"] == .int(3))
    }

    @Test func statusDecodesFromWireJSONWithAbsentOptionalKeys() throws {
        let json = """
        {"owner":"colourSpace","ownerConnected":false,"blanked":"idle",
         "blankRequester":"local","blankPending":false,"epoch":"\(epoch)","revision":12}
        """
        let status = try JSONDecoder().decode(OutputStatus.self, from: Data(json.utf8))
        #expect(status.owner == .colourSpace)
        #expect(status.blanked == .idle)
        #expect(status.blankRequester == .local)
        #expect(status.failure == nil)
        #expect(status.idleBlankSeconds == nil)
        #expect(status.revision == 12)
    }

    @Test func wireEnumsUseSpecifiedRawValues() {
        #expect(PSOutputOwner.allCases.map(\.rawValue) ==
                ["none", "colourSpace", "calman", "pGenerator", "jsonClient", "local"])
        #expect(PSOutputBlankReason.allCases.map(\.rawValue) == ["manual", "idle", "remote"])
        #expect(PSOutputFailure.allCases.map(\.rawValue) == ["notPresented", "outputUnknown"])
    }

    // MARK: - Optional output on existing payloads

    private var sampleStatus: OutputStatus {
        OutputStatus(
            owner: .jsonClient, ownerConnected: true, blankRequester: .jsonClient,
            blanked: .manual, blankPending: false, failure: nil,
            idleBlankSeconds: 120, epoch: epoch, revision: 9
        )
    }

    @Test func oldDeviceStatusDecodesWithNilOutput() throws {
        let json = #"{"currentPatternId":"Color-One-Red","sourceActive":true}"#
        let status = try JSONDecoder().decode(DeviceStatus.self, from: Data(json.utf8))
        #expect(status.output == nil)
    }

    @Test func deviceStatusOutputRoundTrips() throws {
        let status = DeviceStatus(
            currentPatternId: nil, sourceActive: true, selectedSource: "json",
            selectedDisplayId: nil, displayProfileResolved: nil, authRequired: true,
            connectedClientCount: 1, appVersion: nil, buildNumber: nil,
            sdkVersion: nil, protocolVersion: nil, output: sampleStatus
        )
        #expect(try roundTrip(status).output == sampleStatus)
        #expect(DeviceStatus(currentPatternId: nil, sourceActive: false).output == nil)
    }

    @Test func oldDeviceSnapshotDecodesWithNilOutput() throws {
        let json = """
        {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
         "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full",
         "currentPatternId":null,"sourceActive":false}
        """
        let snapshot = try JSONDecoder().decode(DeviceSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.output == nil)
    }

    @Test func deviceSnapshotOutputRoundTrips() throws {
        let snapshot = DeviceSnapshot(
            name: "PS", resolution: Resolution(width: 1920, height: 1080), colorFormat: "RGB",
            bitDepth: 10, hdrMode: "SDR", refreshRate: 60, outputRange: "full",
            currentPatternId: nil, sourceActive: true, output: sampleStatus
        )
        #expect(try roundTrip(snapshot) == snapshot)
    }

    @Test func oldConnectionReadyDecodesWithNilOutput() throws {
        let json = """
        {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
         "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full",
         "currentPatternId":null,"sourceActive":true,
         "protocolVersion":"1.0","authenticated":true}
        """
        let params = try JSONDecoder().decode(ConnectionReadyParams.self, from: Data(json.utf8))
        #expect(params.output == nil)
    }

    @Test func connectionReadyOutputRoundTrips() throws {
        let params = ConnectionReadyParams(
            protocolVersion: "1.3", name: "PS", resolution: Resolution(width: 1920, height: 1080),
            colorFormat: "RGB", bitDepth: 10, hdrMode: "SDR", refreshRate: 60,
            outputRange: "full", currentPatternId: nil, sourceActive: true,
            authenticated: true, output: sampleStatus
        )
        #expect(try roundTrip(params).output == sampleStatus)
    }

    // MARK: - Capability

    private func capabilities(outputBlank: Bool?) -> CapabilitiesResult {
        CapabilitiesResult(
            protocolVersion: "1.3",
            app: AppMetadata(name: "PatternSpace", version: "2.3.0", build: "1"),
            sdkVersion: "1.0.0",
            platform: .macOS,
            authRequired: true,
            namespaces: ["output": ["blank", "resume"]],
            features: CapabilityFeatures(
                events: true, displayInventory: true, peakWhiteControl: true,
                outputColorPresets: true, measurementRange: true, catalogPatterns: true,
                customICCBuilder: false, httpBridge: false
            ),
            outputBlank: outputBlank
        )
    }

    @Test func capabilitiesOutputBlankRoundTrips() throws {
        let result = capabilities(outputBlank: true)
        #expect(try roundTrip(result).outputBlank == true)
        #expect(try jsonObject(result)["outputBlank"] == .bool(true))
    }

    @Test func oldCapabilitiesDecodeWithNilOutputBlank() throws {
        var object = try jsonObject(capabilities(outputBlank: nil))
        object["outputBlank"] = nil
        let data = try JSONEncoder().encode(JSONValue.object(object))
        let decoded = try JSONDecoder().decode(CapabilitiesResult.self, from: data)
        #expect(decoded.outputBlank == nil)
    }
}
