// Tests/PatternSpaceSDKServerTests/JSONRPCDispatcherTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKServer
import PatternSpaceSDKCore

// MARK: - Mock delegate

final class MockDelegate: PatternSpaceServerDelegate, @unchecked Sendable {
    var isSourceActive: Bool = true
    var currentResolution: Resolution = Resolution(width: 3840, height: 2160)

    var displayedPatternId: String?
    var displayedColor: PSColor?
    var displayedBitDepth: BitDepth?
    var displayedPatch: PatchParams?
    var clearCalled = false
    var shouldThrowNotFound = false

    func displayPattern(id: String) async throws {
        if shouldThrowNotFound { throw PSDispatchError(.patternNotFound) }
        displayedPatternId = id
    }
    func displayColor(_ color: PSColor, bitDepth: BitDepth) async throws {
        displayedColor = color; displayedBitDepth = bitDepth
    }
    func displayPatch(_ params: PatchParams) async throws { displayedPatch = params }
    func clearDisplay() async throws { clearCalled = true }
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

func request(method: String, params: String = "{}") -> Data {
    Data(#"{"jsonrpc":"2.0","id":"1","method":"\#(method)","params":\#(params)}"#.utf8)
}

func responseObject(from data: Data) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: data)
}

// MARK: - Tests

@Suite struct JSONRPCDispatcherTests {
    @Test func patternDisplayCallsDelegate() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.display",
                                            params: #"{"patternId":"Color-One-Red"}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["result"] != nil)
        #expect(mock.displayedPatternId == "Color-One-Red")
    }
    @Test func patternDisplayReturnsErrorWhenSourceInactive() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.display",
                                            params: #"{"patternId":"Color-One-Red"}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32005))
    }
    @Test func displayColorValidatesRange() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.displayColor",
                                            params: #"{"r":2.0,"g":0.0,"b":0.0,"bitDepth":10}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32602))
    }
    @Test func displayColorWithSizeMapsToCenteredPatch() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.displayColor",
                                            params: #"{"r":1.0,"g":0.0,"b":0.0,"bitDepth":10,"size":10}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["result"] != nil)
        let patch = try #require(mock.displayedPatch)
        #expect(patch.background == PSColor(r: 0, g: 0, b: 0))
        #expect(patch.rectangles.count == 1)
        #expect(patch.rectangles[0].color == PSColor(r: 1, g: 0, b: 0))
        #expect(abs(patch.rectangles[0].x - 0.341886) < 0.0001)
        #expect(abs(patch.rectangles[0].width - 0.316227) < 0.0001)
        #expect(patch.bitDepth == .ten)
    }
    @Test func displayPatchCallsDelegateWithMultipleRectangles() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.displayPatch", params: """
        {
          "background":{"r":0.0,"g":0.0,"b":0.0},
          "rectangles":[
            {"color":{"r":1.0,"g":0.0,"b":0.0},"x":0.0,"y":0.0,"width":0.5,"height":0.5},
            {"color":{"r":0.0,"g":1.0,"b":0.0},"x":0.5,"y":0.5,"width":0.5,"height":0.5}
          ],
          "bitDepth":10
        }
        """))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["result"] != nil)
        let patch = try #require(mock.displayedPatch)
        #expect(patch.rectangles.count == 2)
        #expect(patch.rectangles[1].color == PSColor(r: 0, g: 1, b: 0))
        #expect(patch.rectangles[1].x == 0.5)
    }
    @Test func displayPatchRejectsEmptyRectangleList() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.displayPatch", params: """
        {"background":{"r":0.0,"g":0.0,"b":0.0},"rectangles":[],"bitDepth":10}
        """))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32602))
    }
    @Test func displayRectangleIsNoLongerSupported() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.displayRectangle",
                                            params: #"{"foreground":{"r":1,"g":1,"b":1},"background":{"r":0,"g":0,"b":0},"x":0,"y":0,"width":1,"height":1,"bitDepth":10}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32601))
    }
    @Test func unknownMethodReturnsMethodNotFound() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "nonexistent.method"))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32601))
    }
    @Test func rpcNamespaceReturnsMethodNotFound() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "rpc.discover"))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32601))
    }
    @Test func invalidJSONReturnsParseError() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(Data("not json".utf8))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32700))
        #expect(obj.object?["id"] == .null)
    }
    @Test func batchRequestReturnsInvalidRequest() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(Data("[{}]".utf8))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32600))
        #expect(obj.object?["id"] == .null)
    }
    @Test func missingIdReturnsInvalidRequest() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(Data(#"{"jsonrpc":"2.0","method":"pattern.clear","params":{}}"#.utf8))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32600))
        #expect(obj.object?["id"] == .null)
    }
    @Test func nullIdReturnsInvalidRequest() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(Data(#"{"jsonrpc":"2.0","id":null,"method":"pattern.clear","params":{}}"#.utf8))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32600))
    }
    @Test func wrongJsonrpcVersionReturnsInvalidRequest() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(Data(#"{"jsonrpc":"1.0","id":"1","method":"device.info","params":{}}"#.utf8))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32600))
    }
    @Test func patternListAlwaysSucceedsWithInactiveSource() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.list", params: "{}"))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["result"] != nil)
    }
    @Test func deviceInfoAlwaysSucceeds() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "device.info", params: "{}"))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["result"]?.object?["name"] == .string("Test"))
    }
    @Test func clearCallsDelegate() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.clear", params: "{}"))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["result"] != nil)
        #expect(mock.clearCalled)
    }
    @Test func patternGetReturnsNotFoundError() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(request(method: "pattern.get",
                                            params: #"{"patternId":"unknown"}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32002))
    }

    // MARK: - Display API tests

    @Test func displayListAlwaysSucceedsWithInactiveSource() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.list", params: "{}"))
        let obj = try responseObject(from: resp)

        #expect(obj.object?["result"]?.object?["platform"] == .string("macOS"))
        #expect(obj.object?["result"]?.object?["selectedDisplayId"] == .string("69734272"))
    }

    @Test func displaySetPeakWhiteDoesNotRequireActiveSource() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.setPeakWhite",
                                            params: #"{"displayId":"69734272","peakWhite":3.0}"#))
        let obj = try responseObject(from: resp)

        #expect(obj.object?["result"]?.object?["id"] == .string("69734272"))
        #expect(obj.object?["result"]?.object?["peakWhite"]?.number == 3.0)
        #expect(mock.setPeakWhiteCalls == [SetPeakWhiteParams(displayId: "69734272", peakWhite: 3.0)])
    }

    @Test func displaySetPeakWhiteRejectsMissingDisplayId() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.setPeakWhite",
                                            params: #"{"peakWhite":3.0}"#))
        let obj = try responseObject(from: resp)

        #expect(obj.object?["error"]?.object?["code"] == .int(-32602))
    }

    @Test func displaySetPeakWhiteRejectsNonFiniteValue() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.setPeakWhite",
                                            params: #"{"displayId":"69734272","peakWhite":"NaN"}"#))
        let obj = try responseObject(from: resp)

        #expect(obj.object?["error"]?.object?["code"] == .int(-32602))
    }

    @Test func displaySetPeakWhiteReturnsRangeErrorData() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.setPeakWhite",
                                            params: #"{"displayId":"69734272","peakWhite":12.0}"#))
        let obj = try responseObject(from: resp)
        let error = try #require(obj.object?["error"]?.object)
        let data = try #require(error["data"]?.object)

        #expect(error["code"] == .int(-32008))
        #expect(data["displayId"] == .string("69734272"))
        #expect(data["peakWhite"]?.number == 12.0)
        #expect(data["minimum"]?.number == 0.25)
        #expect(data["maximum"]?.number == 4.0)
    }

    @Test func capabilitiesListReturnsManifestPreAuthDiscovery() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "capabilities.list", params: "{}"))
        let obj = try responseObject(from: resp)
        let result = try #require(obj.object?["result"]?.object)

        #expect(result["authRequired"] == .bool(true))
        #expect(result["namespaces"]?.object?["capabilities"]?.array == [.string("list")])
    }

    @Test func displayListColorManagementModesIsRemoved() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.listColorManagementModes",
                                            params: #"{"displayId":"69734272"}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32601))
    }

    @Test func displaySetColorManagementModeIsRemoved() async throws {
        let mock = MockDelegate()
        mock.isSourceActive = false
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(method: "display.setColorManagementMode",
                                            params: #"{"displayId":"69734272","mode":"managedDisplayP3"}"#))
        let obj = try responseObject(from: resp)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32601))
    }

    @Test func routeManifestIncludesOutputColorPresetRoutes() {
        #expect(JSONRPCDispatcher.routeManifest["display"]?.contains("listOutputColorPresets") == true)
        #expect(JSONRPCDispatcher.routeManifest["display"]?.contains("getOutputColorPreset") == true)
        #expect(JSONRPCDispatcher.routeManifest["display"]?.contains("setOutputColorPreset") == true)
        #expect(JSONRPCDispatcher.routeManifest["display"]?.contains("listColorManagementModes") != true)
        #expect(JSONRPCDispatcher.routeManifest["display"]?.contains("setColorManagementMode") != true)
    }

    @Test func displayListOutputColorPresetsDispatchesOpenStringIDs() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(
            method: "display.listOutputColorPresets",
            params: #"{"displayId":"69734272"}"#
        ))
        let obj = try responseObject(from: resp)
        let result = try #require(obj.object?["result"]?.object)

        #expect(result["selectedPresetId"] == .string("hdrBT2020PQ"))
        #expect(result["catalogRevision"] == .string("test-catalog"))
        #expect(result["presets"]?.array?.first?.object?["id"] == .string("hdrBT2020PQ"))
        #expect(result["presets"]?.array?.first?.object?["gamut"] == nil)
    }

    @Test func displayGetOutputColorPresetReturnsFullKnownPresetConfig() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(
            method: "display.getOutputColorPreset",
            params: #"{"displayId":"69734272","presetId":"hdrBT2020PQ"}"#
        ))
        let obj = try responseObject(from: resp)
        let result = try #require(obj.object?["result"]?.object)
        let preset = try #require(result["preset"]?.object)

        #expect(result["displayId"] == .string("69734272"))
        #expect(result["catalogRevision"] == .string("test-catalog"))
        #expect(preset["id"] == .string("hdrBT2020PQ"))
        #expect(preset["gamut"] == .string("bt2020"))
        #expect(preset["inputEncoding"] == .string("pqSt2084"))
        #expect(mock.getOutputColorPresetCalls == [GetOutputColorPresetParams(displayId: "69734272", presetId: .hdrBT2020PQ)])
    }

    @Test func displayGetOutputColorPresetReturnsKnownUnsupportedPresetConfig() async throws {
        let mock = MockDelegate()
        mock.unsupportedOutputPresetConfig = OutputColorPresetConfig(
            id: .hdrBT2020PQ,
            label: "BT.2020 PQ",
            group: "hdr",
            family: .hdrReference,
            gamut: .bt2020,
            whitePoint: .d65,
            transfer: .pqSt2084,
            dynamicRange: .hdr,
            toneMapping: .none,
            inputEncoding: .pqSt2084,
            implementationStatus: .insufficientHeadroom,
            supported: false,
            requiresPro: true,
            unsupportedReason: "insufficientHeadroom"
        )
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(
            method: "display.getOutputColorPreset",
            params: #"{"displayId":"69734272","presetId":"hdrBT2020PQ"}"#
        ))
        let obj = try responseObject(from: resp)
        let preset = try #require(obj.object?["result"]?.object?["preset"]?.object)

        #expect(preset["id"] == .string("hdrBT2020PQ"))
        #expect(preset["supported"] == .bool(false))
        #expect(preset["implementationStatus"] == .string("insufficientHeadroom"))
        #expect(preset["unsupportedReason"] == .string("insufficientHeadroom"))
    }

    @Test func displayGetOutputColorPresetRejectsUnknownPresetOnly() async throws {
        let mock = MockDelegate()
        mock.unknownOutputPresetIds = [OutputColorPresetID(rawValue: "vendor.unknown")]
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(
            method: "display.getOutputColorPreset",
            params: #"{"displayId":"69734272","presetId":"vendor.unknown"}"#
        ))
        let obj = try responseObject(from: resp)
        let error = try #require(obj.object?["error"]?.object)
        let data = try #require(error["data"]?.object)

        #expect(error["code"] == .int(PSErrorCode.outputColorPresetUnsupported.rawValue))
        #expect(data["requestedPresetId"] == .string("vendor.unknown"))
        #expect(data["reason"] == .string("unknownPreset"))
    }

    @Test func displaySetOutputColorPresetDispatchesUnknownStringToDelegate() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)

        let resp = await d.dispatch(request(
            method: "display.setOutputColorPreset",
            params: #"{"displayId":"69734272","presetId":"vendor.future"}"#
        ))
        let obj = try responseObject(from: resp)

        #expect(obj.object?["result"] != nil)
        #expect(mock.setOutputColorPresetCalls.first?.presetId.rawValue == "vendor.future")
    }

    @Test func routeManifestMethodsDispatchWithoutMethodNotFound() async throws {
        for method in JSONRPCRoute.allCases.map(\.rawValue) {
            let mock = MockDelegate()
            let d = JSONRPCDispatcher(delegate: mock)
            let resp = await d.dispatch(request(method: method, params: params(for: method)))
            let obj = try responseObject(from: resp)

            #expect(obj.object?["error"]?.object?["code"] != .int(-32601))
        }
    }

    private func params(for method: String) -> String {
        switch method {
        case "pattern.display", "pattern.get":
            return #"{"patternId":"Color-One-Red"}"#
        case "pattern.displayColor":
            return #"{"r":1.0,"g":0.0,"b":0.0,"bitDepth":10}"#
        case "pattern.displayPatch":
            return #"{"background":{"r":0.0,"g":0.0,"b":0.0},"rectangles":[{"color":{"r":1.0,"g":0.0,"b":0.0},"x":0.0,"y":0.0,"width":1.0,"height":1.0}],"bitDepth":10}"#
        case "display.setPeakWhite":
            return #"{"displayId":"69734272","peakWhite":3.0}"#
        case "display.listOutputColorPresets":
            return #"{"displayId":"69734272"}"#
        case "display.getOutputColorPreset":
            return #"{"displayId":"69734272","presetId":"hdrBT2020PQ"}"#
        case "display.setOutputColorPreset":
            return #"{"displayId":"69734272","presetId":"hdrBT2020PQ"}"#
        default:
            return "{}"
        }
    }
}
