// Tests/PatternSpaceSDKServerTests/OutputControlDispatchTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKServer
import PatternSpaceSDKCore

/// Host that does not implement output blank: it must opt out explicitly.
final class UnsupportedBlankDelegate: PatternSpaceServerDelegate, @unchecked Sendable {
    var isSourceActive: Bool = true

    func displayPattern(id: String, context: OutputRequestContext) async throws {}
    func displayColor(_ color: PSColor, bitDepth: BitDepth, context: OutputRequestContext) async throws {}
    func displayPatch(_ params: PatchParams, context: OutputRequestContext) async throws {}
    func clearDisplay(context: OutputRequestContext) async throws {}
    func blankOutput(context: OutputRequestContext) async throws -> OutputStatus {
        throw PSDispatchError(.methodNotFound)
    }
    func resumeOutput(context: OutputRequestContext) async throws -> OutputStatus {
        throw PSDispatchError(.methodNotFound)
    }
    func listPatterns(category: String?, subcategory: String?) async throws -> [PatternInfo] { [] }
    func getPattern(id: String) async throws -> PatternInfo { throw PSDispatchError(.patternNotFound) }
    func deviceInfo() async throws -> DeviceInfo {
        DeviceInfo(name: "Old", resolution: Resolution(width: 1, height: 1), colorFormat: "RGB",
                   bitDepth: 8, hdrMode: "SDR", refreshRate: 60, outputRange: "full")
    }
    func deviceStatus() async throws -> DeviceStatus { DeviceStatus(currentPatternId: nil, sourceActive: true) }
    func capabilities() async throws -> CapabilitiesResult { throw PSDispatchError(.internalError) }
    func listDisplays() async throws -> DisplayListResult {
        DisplayListResult(platform: .macOS, selectedDisplayId: nil, displays: [])
    }
    func setPeakWhite(_ params: SetPeakWhiteParams) async throws -> DisplayEntry {
        throw PSDispatchError(.displayNotFound)
    }
}

private func outputRequest(method: String, rawParams: String?) -> Data {
    let paramsField = rawParams.map { #","params":\#($0)"# } ?? ""
    return Data(#"{"jsonrpc":"2.0","id":"1","method":"\#(method)"\#(paramsField)}"#.utf8)
}

private func errorCode(_ data: Data) throws -> JSONValue? {
    try responseObject(from: data).object?["error"]?.object?["code"]
}

@Suite struct OutputControlDispatchTests {
    private let outputMethods = ["output.blank", "output.resume"]

    @Test func routeManifestListsOutputNamespace() {
        #expect(JSONRPCDispatcher.routeManifest["output"]?.sorted() == ["blank", "resume"])
    }

    @Test func outputNotConfirmedUsesUnusedCode() {
        #expect(PSErrorCode.outputNotConfirmed.rawValue == -32013)
        #expect(PSErrorCode.outputNotConfirmed.defaultMessage == "Output not confirmed")
    }

    @Test(arguments: [nil, "{}", "[]"] as [String?])
    func outputMethodsAcceptEmptyParams(_ rawParams: String?) async throws {
        for method in outputMethods {
            let mock = MockDelegate()
            let d = JSONRPCDispatcher(delegate: mock)
            let resp = await d.dispatch(outputRequest(method: method, rawParams: rawParams),
                                        context: testContext)
            let result = try #require(try responseObject(from: resp).object?["result"]?.object)
            #expect(result["epoch"] == .string(mock.outputStatus.epoch))
            #expect(result["revision"] == .int(Int(mock.outputStatus.revision)))
            #expect(mock.blankContexts.count + mock.resumeContexts.count == 1)
        }
    }

    @Test(arguments: [#"{"force":true}"#, "[1]", "null", "1", #""x""#, "true"])
    func outputMethodsRejectNonEmptyOrScalarParams(_ rawParams: String) async throws {
        for method in outputMethods {
            let mock = MockDelegate()
            let d = JSONRPCDispatcher(delegate: mock)
            let resp = await d.dispatch(outputRequest(method: method, rawParams: rawParams),
                                        context: testContext)
            #expect(try errorCode(resp) == .int(-32602))
            #expect(mock.blankContexts.isEmpty && mock.resumeContexts.isEmpty)
        }
    }

    @Test func outputMethodsRequireActiveSource() async throws {
        for method in outputMethods {
            let mock = MockDelegate()
            mock.isSourceActive = false
            let d = JSONRPCDispatcher(delegate: mock)
            let resp = await d.dispatch(outputRequest(method: method, rawParams: "{}"),
                                        context: testContext)
            #expect(try errorCode(resp) == .int(-32005))
            #expect(mock.blankContexts.isEmpty && mock.resumeContexts.isEmpty)
        }
    }

    @Test func blankEncodesReturnedStatus() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let resp = await d.dispatch(outputRequest(method: "output.blank", rawParams: "{}"),
                                    context: testContext)
        let result = try #require(try responseObject(from: resp).object?["result"])
        let decoded = try JSONDecoder().decode(OutputStatus.self, from: JSONEncoder().encode(result))
        #expect(decoded == mock.outputStatus)
    }

    @Test func blankFailureMapsToOutputNotConfirmed() async throws {
        let mock = MockDelegate()
        mock.outputError = PSDispatchError(.outputNotConfirmed)
        let d = JSONRPCDispatcher(delegate: mock)
        for method in outputMethods {
            let resp = await d.dispatch(outputRequest(method: method, rawParams: nil), context: testContext)
            #expect(try errorCode(resp) == .int(-32013))
        }
    }

    @Test func requestIdentityReachesEveryOutputWrite() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let context = OutputRequestContext(clientID: UUID())
        let requests: [(String, String)] = [
            ("pattern.display", #"{"patternId":"Color-One-Red"}"#),
            ("pattern.displayColor", #"{"r":1.0,"g":0.0,"b":0.0,"bitDepth":10}"#),
            ("pattern.displayColor", #"{"r":1.0,"g":0.0,"b":0.0,"bitDepth":10,"size":10}"#),
            ("pattern.displayPatch", #"{"background":{"r":0.0,"g":0.0,"b":0.0},"rectangles":[{"color":{"r":1.0,"g":0.0,"b":0.0},"x":0.0,"y":0.0,"width":1.0,"height":1.0}],"bitDepth":10}"#),
            ("pattern.clear", "{}"),
            ("output.blank", "{}"),
            ("output.resume", "{}"),
        ]
        for (method, params) in requests {
            let resp = await d.dispatch(request(method: method, params: params), context: context)
            #expect(try responseObject(from: resp).object?["result"] != nil, "\(method)")
        }
        #expect(mock.patternContexts == [context])
        #expect(mock.colorContexts == [context])
        #expect(mock.patchContexts == [context, context])
        #expect(mock.clearContexts == [context])
        #expect(mock.blankContexts == [context])
        #expect(mock.resumeContexts == [context])
    }

    @Test func distinctClientsKeepDistinctIdentities() async throws {
        let mock = MockDelegate()
        let d = JSONRPCDispatcher(delegate: mock)
        let first = OutputRequestContext(clientID: UUID())
        let second = OutputRequestContext(clientID: UUID())
        async let a = d.dispatch(outputRequest(method: "output.blank", rawParams: nil), context: first)
        async let b = d.dispatch(outputRequest(method: "output.blank", rawParams: nil), context: second)
        _ = await (a, b)
        #expect(Set(mock.blankContexts.map(\.clientID)) == [first.clientID, second.clientID])
    }

    @Test func unsupportedHostReturnsMethodNotFound() async throws {
        let host = UnsupportedBlankDelegate()
        let d = JSONRPCDispatcher(delegate: host)
        for method in outputMethods {
            let resp = await d.dispatch(outputRequest(method: method, rawParams: "{}"), context: testContext)
            #expect(try errorCode(resp) == .int(-32601))
        }
    }
}
