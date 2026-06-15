import Foundation
import Testing
@testable import PatternSpaceSDKCore

@Suite struct DisplaySchemasTests {
    @Test func displayEntryDecodesStoredAndEffectivePeakWhite() throws {
        let json = """
        {
          "id":"69734272",
          "name":"Studio Display",
          "selected":true,
          "connection":"wired",
          "resolution":{"width":5120,"height":2880},
          "refreshRate":60,
          "colorSpaceName":"Display P3",
          "cgColorSpaceName":"kCGColorSpaceDisplayP3",
          "maximumPotentialEDR":4.0,
          "maximumCurrentEDR":2.0,
          "peakWhite":4.0,
          "effectivePeakWhite":2.0,
          "peakWhiteRange":{"minimum":0.25,"maximum":4.0},
          "supportsPeakWhiteControl":true
        }
        """

        let entry = try JSONDecoder().decode(DisplayEntry.self, from: Data(json.utf8))

        #expect(entry.id == "69734272")
        #expect(entry.connection == .wired)
        #expect(entry.peakWhite == 4.0)
        #expect(entry.effectivePeakWhite == 2.0)
        #expect(entry.peakWhiteRange.minimum == PeakWhiteRange.absoluteMinimum)
        #expect(entry.peakWhiteRange.maximum == 4.0)
    }

    @Test func displayEntryDecodesColorManagementFieldsAndIgnoresUnknownKeys() throws {
        let json = """
        {
          "id":"69734272",
          "name":"Studio Display",
          "selected":true,
          "connection":"wired",
          "resolution":{"width":5120,"height":2880},
          "refreshRate":60,
          "colorSpaceName":"Display P3",
          "cgColorSpaceName":"kCGColorSpaceDisplayP3",
          "maximumPotentialEDR":4.0,
          "maximumCurrentEDR":2.0,
          "peakWhite":4.0,
          "effectivePeakWhite":2.0,
          "peakWhiteRange":{"minimum":0.25,"maximum":4.0},
          "supportsPeakWhiteControl":true,
          "colorManagementMode":"deviceNative",
          "supportedColorManagementModes":["deviceNative","managedSRGB","managedDisplayP3","managedRec2020"],
          "colorManagementImplementationStatus":"native",
          "colorManagementScope":"host",
          "displayProfileResolved":true,
          "futureField":"ignored"
        }
        """

        let entry = try JSONDecoder().decode(DisplayEntry.self, from: Data(json.utf8))

        #expect(entry.colorManagementMode == .deviceNative)
        #expect(entry.supportedColorManagementModes == [.deviceNative, .managedSRGB, .managedDisplayP3, .managedRec2020])
        #expect(entry.colorManagementImplementationStatus == .native)
        #expect(entry.colorManagementScope == .host)
        #expect(entry.displayProfileResolved == true)
    }

    @Test func outputColorPresetIDPreservesUnknownRawValue() throws {
        let data = #""vendor.customPQ""#.data(using: .utf8)!

        let id = try JSONDecoder().decode(OutputColorPresetID.self, from: data)
        let encoded = try JSONEncoder().encode(id)

        #expect(id.rawValue == "vendor.customPQ")
        #expect(String(data: encoded, encoding: .utf8) == #""vendor.customPQ""#)
    }

    @Test func outputColorPresetDecodesHDRDiagnosticsAndUnknownFields() throws {
        let json = """
        {
          "id":"hdrBT2020PQ",
          "label":"BT.2020 PQ",
          "group":"hdr",
          "dynamicRange":"hdr",
          "gamut":"bt2020",
          "whitePoint":"d65",
          "transferFunction":"pqSt2084",
          "measurementRange":"full",
          "toneMapping":"none",
          "implementationStatus":"native",
          "supported":true,
          "requiresPro":true,
          "edrHeadroomRequired":2.0,
          "edrHeadroomPotential":4.0,
          "edrHeadroomCurrent":2.0,
          "edrHeadroomReference":1.0,
          "referenceWhiteNits":100.0,
          "referenceWhiteNitsSource":"defaultCalibration100",
          "peakLuminanceNits":200.0,
          "clipOnsetNits":200.0,
          "clipOnsetPQSignal":0.579,
          "futureField":"ignored"
        }
        """

        let preset = try JSONDecoder().decode(OutputColorPreset.self, from: Data(json.utf8))

        #expect(preset.id == .hdrBT2020PQ)
        #expect(preset.implementationStatus == "native")
        #expect(preset.clipOnsetNits == 200)
        #expect(preset.clipOnsetPQSignal == 0.579)
    }

    @Test func displayEntryDecodesOutputPresetFieldsAndNilLegacyHDRFields() throws {
        let json = """
        {
          "id":"69734272",
          "name":"Studio Display",
          "selected":true,
          "connection":"wired",
          "resolution":{"width":5120,"height":2880},
          "maximumPotentialEDR":4.0,
          "maximumCurrentEDR":2.0,
          "peakWhite":1.0,
          "effectivePeakWhite":1.0,
          "peakWhiteRange":{"minimum":0.25,"maximum":4.0},
          "supportsPeakWhiteControl":true,
          "supportedColorManagementModes":["deviceNative","managedSRGB"],
          "outputColorPresetId":"hdrBT2020PQ",
          "supportedOutputColorPresetIds":["deviceNative","hdrBT2020PQ"],
          "outputColorPresetImplementationStatus":"native"
        }
        """

        let entry = try JSONDecoder().decode(DisplayEntry.self, from: Data(json.utf8))

        #expect(entry.colorManagementMode == nil)
        #expect(entry.colorManagementImplementationStatus == nil)
        #expect(entry.colorManagementScope == nil)
        #expect(entry.outputColorPresetId == .hdrBT2020PQ)
        #expect(entry.supportedOutputColorPresetIds.contains(.deviceNative))
        #expect(entry.outputColorPresetImplementationStatus == "native")
    }

    @Test func displayListResultEncodesPlatformAtTopLevel() throws {
        let entry = DisplayEntry(
            id: "ios-output",
            name: "This iPhone",
            selected: true,
            connection: .builtIn,
            resolution: Resolution(width: 1179, height: 2556),
            refreshRate: 120,
            colorSpaceName: "Display P3",
            cgColorSpaceName: "Display P3",
            maximumPotentialEDR: 1.8,
            maximumCurrentEDR: 1.5,
            peakWhite: 1.8,
            effectivePeakWhite: 1.5,
            peakWhiteRange: PeakWhiteRange(maximum: 1.8),
            supportsPeakWhiteControl: true
        )
        let result = DisplayListResult(platform: .iOS, selectedDisplayId: "ios-output", displays: [entry])

        let data = try JSONEncoder().encode(result)
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)

        #expect(obj.object?["platform"] == .string("iOS"))
        #expect(obj.object?["selectedDisplayId"] == .string("ios-output"))
        #expect(obj.object?["displays"]?.array?.count == 1)
    }

    @Test func absoluteMinimumIsProtocolValue() {
        #expect(PeakWhiteRange.absoluteMinimum == 0.25)
    }

    @Test func displayErrorCodesAreStable() {
        #expect(PSErrorCode.displayNotFound.rawValue == -32007)
        #expect(PSErrorCode.peakWhiteOutOfRange.rawValue == -32008)
        #expect(PSErrorCode.notAuthorized.rawValue == -32009)
        #expect(PSErrorCode.colorManagementModeUnsupported.rawValue == -32010)
        #expect(PSErrorCode.displaySelectionMismatch.rawValue == -32011)
        #expect(PSErrorCode.outputColorPresetUnsupported.rawValue == -32012)
    }
}
