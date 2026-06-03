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
}
