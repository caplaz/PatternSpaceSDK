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
    @Test func deviceStatusDecodesRuntimeMetadataAndIgnoresUnknownKeys() throws {
        let json = """
        {
          "currentPatternId":"Color-One-Red",
          "sourceActive":true,
          "selectedSource":"json",
          "selectedDisplayId":"69734272",
          "colorManagementMode":"deviceNative",
          "colorManagementImplementationStatus":"native",
          "displayProfileResolved":true,
          "colorManagementScope":"host",
          "authRequired":true,
          "connectedClientCount":1,
          "appVersion":"1.1.0",
          "buildNumber":"123",
          "sdkVersion":"0.4.1",
          "protocolVersion":"1.1",
          "outputColorPresetId":"hdrBT2020PQ",
          "outputColorPresetImplementationStatus":"native",
          "edrHeadroomPotential":4.0,
          "edrHeadroomCurrent":2.0,
          "edrHeadroomReference":1.0,
          "referenceWhiteNits":100.0,
          "referenceWhiteNitsSource":"defaultCalibration100",
          "clipOnsetNits":200.0,
          "clipOnsetPQSignal":0.579,
          "futureField":"ignored"
        }
        """

        let status = try JSONDecoder().decode(DeviceStatus.self, from: Data(json.utf8))

        #expect(status.selectedDisplayId == "69734272")
        #expect(status.colorManagementMode == .deviceNative)
        #expect(status.colorManagementImplementationStatus == .native)
        #expect(status.displayProfileResolved == true)
        #expect(status.colorManagementScope == .host)
        #expect(status.authRequired == true)
        #expect(status.connectedClientCount == 1)
        #expect(status.appVersion == "1.1.0")
        #expect(status.buildNumber == "123")
        #expect(status.sdkVersion == PatternSpaceProtocolMetadata.sdkVersion)
        #expect(status.protocolVersion == PatternSpaceProtocolMetadata.protocolVersion)
        #expect(status.outputColorPresetId == .hdrBT2020PQ)
        #expect(status.outputColorPresetImplementationStatus == "native")
        #expect(status.edrHeadroomPotential == 4.0)
        #expect(status.edrHeadroomCurrent == 2.0)
        #expect(status.edrHeadroomReference == 1.0)
        #expect(status.referenceWhiteNits == 100.0)
        #expect(status.referenceWhiteNitsSource == "defaultCalibration100")
        #expect(status.clipOnsetNits == 200.0)
        #expect(status.clipOnsetPQSignal == 0.579)
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
