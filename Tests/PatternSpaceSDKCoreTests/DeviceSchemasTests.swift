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
    {"currentPatternId":"Color-One-Red","connectedClients":2,"sourceActive":true}
    """
    let snapshotJSON = """
    {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
     "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full",
     "currentPatternId":null,"connectedClients":1,"sourceActive":false}
    """
    let crJSON = """
    {"name":"PS","resolution":{"width":3840,"height":2160},"colorFormat":"RGB",
     "bitDepth":10,"hdrMode":"HDR10","refreshRate":60,"outputRange":"full",
     "currentPatternId":null,"connectedClients":1,"sourceActive":true,
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
        #expect(status.connectedClients == 2)
        #expect(status.sourceActive == true)
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
}
