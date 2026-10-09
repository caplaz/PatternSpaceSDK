import Foundation
import Testing
import PatternSpaceSDKCore
@testable import PatternSpaceSDKServer

@Suite struct SignalDispatchTests {
    private let patch = #""background":{"r":0,"g":0,"b":0},"rectangles":[{"color":{"r":1,"g":0,"b":0},"x":0,"y":0,"width":1,"height":1}],"bitDepth":10"#
    @Test(arguments: ["{}", "[]"])
    func snapshotReadsWhileInactiveAndForwardsContext(_ params: String) async throws {
        let host = MockDelegate(); host.supportsSignalSnapshot = true; host.isSourceActive = false
        let response = await JSONRPCDispatcher(delegate: host).dispatch(request(method: "device.signalSnapshot", params: params), context: testContext)
        #expect(try responseObject(from: response).object?["result"]?.object?["evidence"] != nil)
        #expect(host.signalReadContext == testContext)
        #expect(host.patchContexts.isEmpty)
    }
    @Test(arguments: ["null", "[1]", #"{"extra":1}"#, "true"])
    func snapshotRejectsNonEmptyParams(_ params: String) async throws {
        let host = MockDelegate(); host.supportsSignalSnapshot = true
        let response = await JSONRPCDispatcher(delegate: host).dispatch(request(method: "device.signalSnapshot", params: params), context: testContext)
        #expect(try responseObject(from: response).object?["error"]?.object?["code"] == .int(-32602))
        #expect(host.signalReadContext == nil)
    }
    @Test func unsupportedRoutesRemainMethodNotFoundAndOmitted() async throws {
        let host = MockDelegate()
        host.capabilitiesResult = CapabilitiesResult(protocolVersion: "1.3", app: .init(name: "Old", version: "1", build: "1"),
            sdkVersion: "1.0.0", platform: .macOS, authRequired: true, namespaces: JSONRPCDispatcher.routeManifest,
            features: .init(events: true, displayInventory: true, peakWhiteControl: true, outputColorPresets: true,
                measurementRange: true, catalogPatterns: true, customICCBuilder: false, httpBridge: false,
                signalSnapshot: true, signalProbe: true))
        let dispatcher = JSONRPCDispatcher(delegate: host)
        for method in ["device.signalSnapshot", "pattern.displayProbe"] {
            let response = await dispatcher.dispatch(request(method: method), context: testContext)
            #expect(try responseObject(from: response).object?["error"]?.object?["code"] == .int(-32601))
        }
        let response = await dispatcher.dispatch(request(method: "capabilities.list"), context: testContext)
        let result = try #require(try responseObject(from: response).object?["result"]?.object)
        #expect(result["namespaces"]?.object?["device"]?.array?.contains(.string("signalSnapshot")) == false)
        #expect(result["namespaces"]?.object?["pattern"]?.array?.contains(.string("displayProbe")) == false)
        #expect(result["namespaces"]?.object?["device"]?.array?.contains(.string("info")) == true)
        #expect(result["features"]?.object?["signalSnapshot"] == nil)
        #expect(result["features"]?.object?["signalProbe"] == nil)
    }
    @Test func probeForwardsValidatedPatchAndGuardWithoutFallback() async throws {
        let host = MockDelegate(); host.supportsSignalProbe = true
        let response = await JSONRPCDispatcher(delegate: host).dispatch(request(method: "pattern.displayProbe", params: "{\(patch),\"expectedContextGuard\":\"opaque-guard\"}"), context: testContext)
        #expect(try responseObject(from: response).object?["result"] != nil)
        #expect(host.signalProbeContext == testContext)
        #expect(host.signalProbeParams?.patch.bitDepth == .ten)
        #expect(host.signalProbeParams?.expectedContextGuard == "opaque-guard")
        #expect(host.patchContexts.isEmpty)
    }
    @Test(arguments: ["", "white space", "\n", String(repeating: "a", count: 513)])
    func malformedGuardsRejectedBeforeDelegate(_ guardValue: String) async throws {
        let host = MockDelegate(); host.supportsSignalProbe = true
        let encoded = String(decoding: try JSONEncoder().encode(guardValue), as: UTF8.self)
        let response = await JSONRPCDispatcher(delegate: host).dispatch(request(method: "pattern.displayProbe", params: "{\(patch),\"expectedContextGuard\":\(encoded)}"), context: testContext)
        #expect(try responseObject(from: response).object?["error"]?.object?["code"] == .int(-32602))
        #expect(host.signalProbeParams == nil)
    }
    @Test func probeRequiresSourceAndPreservesHostGuardErrors() async throws {
        let host = MockDelegate(); host.supportsSignalProbe = true; host.isSourceActive = false
        let dispatcher = JSONRPCDispatcher(delegate: host)
        let params = "{\(patch),\"expectedContextGuard\":\"guard\"}"
        let inactive = await dispatcher.dispatch(request(method: "pattern.displayProbe", params: params), context: testContext)
        #expect(try responseObject(from: inactive).object?["error"]?.object?["code"] == .int(-32005))
        #expect(host.signalProbeParams == nil)
        host.isSourceActive = true
        for code in [PSErrorCode.displayError, .notAuthorized] {
            host.signalError = PSDispatchError(code)
            let response = await dispatcher.dispatch(request(method: "pattern.displayProbe", params: params), context: testContext)
            #expect(try responseObject(from: response).object?["error"]?.object?["code"] == .int(code.rawValue))
        }
    }
    @Test func probeAndPatchShareValidation() async throws {
        let host = MockDelegate(); host.supportsSignalProbe = true
        let dispatcher = JSONRPCDispatcher(delegate: host)
        let invalid = patch.replacingOccurrences(of: "\"width\":1", with: "\"width\":2")
        let patchResponse = await dispatcher.dispatch(request(method: "pattern.displayPatch", params: "{\(invalid)}"), context: testContext)
        let probeResponse = await dispatcher.dispatch(request(method: "pattern.displayProbe", params: "{\(invalid),\"expectedContextGuard\":\"guard\"}"), context: testContext)
        #expect(try responseObject(from: patchResponse).object?["error"]?.object?["code"] == responseObject(from: probeResponse).object?["error"]?.object?["code"])
        #expect(host.signalProbeParams == nil && host.patchContexts.isEmpty)
    }
    @Test func snapshotAcceptsAbsentParamsAndBoundsCompleteRPCResponse() async throws {
        let host = MockDelegate(); host.supportsSignalSnapshot = true
        let dispatcher = JSONRPCDispatcher(delegate: host)
        let absent = Data(#"{"jsonrpc":"2.0","id":1,"method":"device.signalSnapshot"}"#.utf8)
        let read = await dispatcher.dispatch(absent, context: testContext)
        #expect(try responseObject(from: read).object?["result"] != nil)
        host.signalSnapshotResponse = .init(evidence: .init(identity: .init(
            diagnosticsEpoch: String(repeating: "e", count: 250_000), revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current))
        let longID = String(repeating: "i", count: 20_000)
        let packet = JSONValue.object(["jsonrpc": .string("2.0"), "id": .string(longID),
            "method": .string("device.signalSnapshot")])
        let oversized = await dispatcher.dispatch(try JSONEncoder().encode(packet), context: testContext)
        #expect(oversized.count <= SignalSnapshotResponse.maximumPayloadBytes)
        #expect(try responseObject(from: oversized).object?["error"]?.object?["code"] == .int(-32603))
    }

    @Test func unchangedOldDelegateUsesDefaultUnsupportedHooks() async throws {
        let oldHost = UnsupportedBlankDelegate()
        #expect(!oldHost.supportsSignalSnapshot && !oldHost.supportsSignalProbe)
        let dispatcher = JSONRPCDispatcher(delegate: oldHost)
        for method in ["device.signalSnapshot", "pattern.displayProbe"] {
            let response = await dispatcher.dispatch(request(method: method), context: testContext)
            #expect(try responseObject(from: response).object?["error"]?.object?["code"] == .int(-32601))
        }
    }

}
