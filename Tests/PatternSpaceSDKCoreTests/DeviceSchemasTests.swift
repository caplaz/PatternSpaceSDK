// Tests/PatternSpaceSDKCoreTests/DeviceSchemasTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKCore

@Suite struct DeviceSchemasTests {
    let infoJSON = """
    {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
     "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full"}
    """
    let statusJSON = """
    {"currentPatternId":"Color-One-Red","sourceActive":true}
    """
    let snapshotJSON = """
    {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
     "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full",
     "currentPatternId":null,"sourceActive":false}
    """
    let crJSON = """
    {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
     "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full",
     "currentPatternId":null,"sourceActive":true,
     "protocolVersion":"1.0","authenticated":true}
    """

    @Test func deviceInfoDecodes() throws {
        let info = try JSONDecoder().decode(DeviceInfo.self, from: Data(infoJSON.utf8))
        #expect(info.resolution.width == 3840)
        #expect(info.colorFormat == "RGB")
    }
    @Test func deviceStatusDecodes() throws {
        let status = try JSONDecoder().decode(DeviceStatus.self, from: Data(statusJSON.utf8))
        #expect(status.currentPatternId == "Color-One-Red")
        #expect(status.sourceActive == true)
    }
    @Test func deviceStatusEncodingOmitsConnectedClients() throws {
        let status = DeviceStatus(currentPatternId: nil, sourceActive: true)
        let data = try JSONEncoder().encode(status)
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)

        #expect(obj.object?["connectedClients"] == nil)
        #expect(obj.object?["sourceActive"] == JSONValue.bool(true))
    }
    @Test func deviceSnapshotDecodesNullPatternId() throws {
        let snap = try JSONDecoder().decode(DeviceSnapshot.self, from: Data(snapshotJSON.utf8))
        #expect(snap.currentPatternId == nil)
        #expect(snap.sourceActive == false)
    }
    @Test func connectionReadyParamsDecodes() throws {
        let params = try JSONDecoder().decode(ConnectionReadyParams.self, from: Data(crJSON.utf8))
        #expect(params.protocolVersion == "1.0")
        #expect(params.authenticated == true)
    }
    @Test func connectionReadyEncodingOmitsConnectedClients() throws {
        let params = ConnectionReadyParams(
            protocolVersion: "1.0",
            name: "PS",
            resolution: Resolution(width: 3840, height: 2160),
            colorFormat: "RGB",
            bitDepth: 10,
            hdrMode: "SDR",
            refreshRate: 60,
            outputRange: "full",
            currentPatternId: nil,
            sourceActive: true,
            authenticated: true
        )
        let data = try JSONEncoder().encode(params)
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)

        #expect(obj.object?["connectedClients"] == nil)
        #expect(obj.object?["authenticated"] == JSONValue.bool(true))
    }
}
