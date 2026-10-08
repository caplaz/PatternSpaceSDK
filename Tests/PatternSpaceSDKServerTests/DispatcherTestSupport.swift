// Tests/PatternSpaceSDKServerTests/JSONRPCDispatcherTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKServer
import PatternSpaceSDKCore

// MARK: - Mock delegate

final class MockDelegate: PatternSpaceServerDelegate, @unchecked Sendable {
    var supportsSignalSnapshot = false
    var supportsSignalProbe = false
    var signalReadContext: OutputRequestContext?
    var signalProbeContext: OutputRequestContext?
    var signalProbeParams: SignalProbeParams?
    var signalError: PSDispatchError?
    var signalSnapshotResponse: SignalSnapshotResponse?
    func signalSnapshot(context: OutputRequestContext) async throws -> SignalSnapshotResponse {
        signalReadContext = context
        if let signalError { throw signalError }
        if let signalSnapshotResponse { return signalSnapshotResponse }
        return .init(evidence: .init(identity: .init(diagnosticsEpoch: "epoch", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current))
    }
    func displayProbe(_ params: SignalProbeParams, context: OutputRequestContext) async throws {
        if let signalError { throw signalError }
        signalProbeParams = params; signalProbeContext = context
    }
    var isSourceActive: Bool = true
    var currentResolution: Resolution = Resolution(width: 3840, height: 2160)

    var displayedPatternId: String?
    var displayedColor: PSColor?
    var displayedBitDepth: BitDepth?
    var displayedPatch: PatchParams?
    var clearCalled = false
    var shouldThrowNotFound = false

    var outputStatus = OutputStatus(
        owner: .jsonClient, ownerConnected: true, blankRequester: .jsonClient,
        blanked: .remote, blankPending: false, failure: nil, idleBlankSeconds: nil,
        epoch: "6F9619FF-8B86-D011-B42D-00C04FC964FF", revision: 5
    )
    var outputError: PSDispatchError?

    // Request contexts received by each output-write method, in call order.
    private let contextLock = NSLock()
    private var recordedContexts: [String: [OutputRequestContext]] = [:]
    private func record(_ method: String, _ context: OutputRequestContext) {
        contextLock.lock(); defer { contextLock.unlock() }
        recordedContexts[method, default: []].append(context)
    }
    private func contexts(_ method: String) -> [OutputRequestContext] {
        contextLock.lock(); defer { contextLock.unlock() }
        return recordedContexts[method] ?? []
    }
    var patternContexts: [OutputRequestContext] { contexts("pattern") }
    var colorContexts: [OutputRequestContext] { contexts("color") }
    var patchContexts: [OutputRequestContext] { contexts("patch") }
    var clearContexts: [OutputRequestContext] { contexts("clear") }
    var blankContexts: [OutputRequestContext] { contexts("blank") }
    var resumeContexts: [OutputRequestContext] { contexts("resume") }

    func displayPattern(id: String, context: OutputRequestContext) async throws {
        record("pattern", context)
        if shouldThrowNotFound { throw PSDispatchError(.patternNotFound) }
        displayedPatternId = id
    }
    func displayColor(_ color: PSColor, bitDepth: BitDepth, context: OutputRequestContext) async throws {
        record("color", context)
        displayedColor = color; displayedBitDepth = bitDepth
    }
    func displayPatch(_ params: PatchParams, context: OutputRequestContext) async throws {
        record("patch", context)
        displayedPatch = params
    }
    func clearDisplay(context: OutputRequestContext) async throws {
        record("clear", context)
        clearCalled = true
    }
    func blankOutput(context: OutputRequestContext) async throws -> OutputStatus {
        record("blank", context)
        if let outputError { throw outputError }
        return outputStatus
    }
    func resumeOutput(context: OutputRequestContext) async throws -> OutputStatus {
        record("resume", context)
        if let outputError { throw outputError }
        return outputStatus
    }
    func listPatterns(category: String?, subcategory: String?) async throws -> [PatternInfo] {
        [PatternInfo(id: "Color-One-Red", name: "Red", category: "Color", subcategory: "Solid")]
    }
    func getPattern(id: String) async throws -> PatternInfo {
        if id == "unknown" { throw PSDispatchError(.patternNotFound) }
        return PatternInfo(id: id, name: "Red", category: "Color", subcategory: "Solid")
    }
    func deviceInfo() async throws -> DeviceInfo {
        DeviceInfo(name: "Test", resolution: currentResolution, colorFormat: "RGB",
                   bitDepth: 10, hdrMode: "SDR", refreshRate: 60, outputRange: "full")
    }
    func deviceStatus() async throws -> DeviceStatus {
        DeviceStatus(currentPatternId: nil, sourceActive: isSourceActive)
    }

    // MARK: - Display API

    var displayList = DisplayListResult(
        platform: .macOS,
        selectedDisplayId: "69734272",
        displays: [
            DisplayEntry(
                id: "69734272",
                name: "Studio Display",
                selected: true,
                connection: .wired,
                resolution: Resolution(width: 5120, height: 2880),
                refreshRate: 60,
                colorSpaceName: "Display P3",
                cgColorSpaceName: "kCGColorSpaceDisplayP3",
                maximumPotentialEDR: 4.0,
                maximumCurrentEDR: 2.0,
                peakWhite: 4.0,
                effectivePeakWhite: 2.0,
                peakWhiteRange: PeakWhiteRange(maximum: 4.0),
                supportsPeakWhiteControl: true
            )
        ]
    )
    var setPeakWhiteCalls: [SetPeakWhiteParams] = []
    var setOutputColorPresetCalls: [SetOutputColorPresetParams] = []
    var setMeasurementRangeCalls: [SetMeasurementRangeParams] = []
    var getOutputColorPresetCalls: [GetOutputColorPresetParams] = []
    var unknownOutputPresetIds: Set<OutputColorPresetID> = []
    var unsupportedOutputPresetConfig: OutputColorPresetConfig?
    var capabilitiesResult = CapabilitiesResult(
        protocolVersion: PatternSpaceProtocolMetadata.protocolVersion,
        app: AppMetadata(name: "PatternSpace", version: "1.1.0", build: "123"),
        sdkVersion: PatternSpaceProtocolMetadata.sdkVersion,
        platform: .macOS,
        authRequired: true,
        namespaces: ["capabilities": ["list"]],
        features: CapabilityFeatures(
            events: true,
            displayInventory: true,
            peakWhiteControl: true,
            outputColorPresets: true,
            measurementRange: false,
            catalogPatterns: true,
            customICCBuilder: false,
            httpBridge: false
        )
    )

    func listDisplays() async throws -> DisplayListResult { displayList }

    func setPeakWhite(_ params: SetPeakWhiteParams) async throws -> DisplayEntry {
        setPeakWhiteCalls.append(params)
        guard let display = displayList.displays.first(where: { $0.id == params.displayId }) else {
            throw PSDispatchError(.displayNotFound, data: .object(["displayId": .string(params.displayId)]))
        }
        guard params.peakWhite >= display.peakWhiteRange.minimum,
              params.peakWhite <= display.peakWhiteRange.maximum else {
            throw PSDispatchError(
                .peakWhiteOutOfRange,
                data: .object([
                    "displayId": .string(params.displayId),
                    "peakWhite": .double(params.peakWhite),
                    "minimum": .double(display.peakWhiteRange.minimum),
                    "maximum": .double(display.peakWhiteRange.maximum)
                ])
            )
        }
        return DisplayEntry(
            id: display.id,
            name: display.name,
            selected: display.selected,
            connection: display.connection,
            resolution: display.resolution,
            refreshRate: display.refreshRate,
            colorSpaceName: display.colorSpaceName,
            cgColorSpaceName: display.cgColorSpaceName,
            maximumPotentialEDR: display.maximumPotentialEDR,
            maximumCurrentEDR: display.maximumCurrentEDR,
            peakWhite: params.peakWhite,
            effectivePeakWhite: min(params.peakWhite, display.maximumCurrentEDR),
            peakWhiteRange: display.peakWhiteRange,
            supportsPeakWhiteControl: display.supportsPeakWhiteControl
        )
    }

    func capabilities() async throws -> CapabilitiesResult { capabilitiesResult }

    func listOutputColorPresets(displayId: String) async throws -> OutputColorPresetList {
        OutputColorPresetList(
            displayId: displayId,
            selectedPresetId: .hdrBT2020PQ,
            scope: .host,
            catalogRevision: "test-catalog",
            presets: [
                OutputColorPresetSummary(
                    id: .hdrBT2020PQ,
                    label: "BT.2020 PQ",
                    group: "hdr",
                    family: .hdrReference,
                    supported: true,
                    requiresPro: true,
                    implementationStatus: .native
                )
            ]
        )
    }

    func getOutputColorPreset(_ params: GetOutputColorPresetParams) async throws -> GetOutputColorPresetResult {
        getOutputColorPresetCalls.append(params)
        if unknownOutputPresetIds.contains(params.presetId) {
            throw PSDispatchError(
                .outputColorPresetUnsupported,
                data: .object([
                    "requestedPresetId": .string(params.presetId.rawValue),
                    "supportedPresetIds": .array([.string(OutputColorPresetID.hdrBT2020PQ.rawValue)]),
                    "scope": .string(ColorManagementScope.host.rawValue),
                    "reason": .string("unknownPreset")
                ])
            )
        }
        return GetOutputColorPresetResult(
            displayId: params.displayId,
            catalogRevision: "test-catalog",
            preset: unsupportedOutputPresetConfig ?? outputPresetConfig(
                id: params.presetId,
                supported: true,
                implementationStatus: .native
            )
        )
    }

    func setOutputColorPreset(_ params: SetOutputColorPresetParams) async throws -> SetOutputColorPresetResult {
        setOutputColorPresetCalls.append(params)
        let display = displayList.displays[0]
        return SetOutputColorPresetResult(
            scope: .host,
            selectedPresetId: params.presetId,
            selectedDisplayId: display.id,
            display: display
        )
    }

    func setMeasurementRange(_ params: SetMeasurementRangeParams) async throws -> SetMeasurementRangeResult {
        setMeasurementRangeCalls.append(params)
        let display = displayList.displays[0]
        return SetMeasurementRangeResult(
            scope: .host,
            selectedMeasurementRange: params.measurementRange,
            selectedDisplayId: display.id,
            display: display
        )
    }

    private func outputPresetConfig(
        id: OutputColorPresetID,
        supported: Bool,
        implementationStatus: OutputColorPresetImplementationStatus
    ) -> OutputColorPresetConfig {
        OutputColorPresetConfig(
            id: id,
            label: "BT.2020 PQ",
            group: "hdr",
            family: .hdrReference,
            gamut: .bt2020,
            whitePoint: .d65,
            transfer: .pqSt2084,
            dynamicRange: .hdr,
            toneMapping: .none,
            inputEncoding: .pqSt2084,
            implementationStatus: implementationStatus,
            supported: supported,
            requiresPro: true,
            unsupportedReason: supported ? nil : "insufficientHeadroom",
            edrHeadroomRequired: 2.0,
            edrHeadroomPotential: 1.2,
            edrHeadroomCurrent: 1.0,
            edrHeadroomReference: 1.0,
            referenceWhiteNits: 100,
            referenceWhiteNitsSource: "configured",
            peakLuminanceNits: 1000,
            clipOnsetNits: 120,
            clipOnsetPQSignal: 0.508
        )
    }
}

// MARK: - Helpers

let testContext = OutputRequestContext(clientID: UUID())

func request(method: String, params: String = "{}") -> Data {
    Data(#"{"jsonrpc":"2.0","id":"1","method":"\#(method)","params":\#(params)}"#.utf8)
}

func responseObject(from data: Data) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: data)
}

