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

    @Test func outputPresetListUsesLightweightSummariesAndCatalogRevision() throws {
        let result = OutputColorPresetList(
            displayId: "69734272",
            selectedPresetId: .sdrReferenceBT709Gamma24,
            scope: .host,
            catalogRevision: "2026-06-16.1",
            presets: [
                OutputColorPresetSummary(
                    id: .sdrReferenceBT709Gamma24,
                    label: "Reference - BT.709 (gamma 2.4)",
                    group: "hdtv",
                    family: .sdrReference,
                    supported: true,
                    requiresPro: true,
                    implementationStatus: .native
                )
            ]
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as! [String: Any]
        let presets = try #require(json["presets"] as? [[String: Any]])
        let first = try #require(presets.first)
        #expect(json["catalogRevision"] as? String == "2026-06-16.1")
        #expect(first["id"] as? String == "sdrReferenceBT709Gamma24")
        #expect(first["family"] as? String == "sdrReference")
        #expect(first["gamut"] == nil)
        #expect(first["transfer"] == nil)
        #expect(first["inputEncoding"] == nil)
    }

    @Test func outputPresetConfigIsSelfDescribingAndOpenStringTyped() throws {
        let config = OutputColorPresetConfig(
            id: .sdrReferenceBT709Gamma24,
            label: "Reference - BT.709 (gamma 2.4)",
            group: "hdtv",
            family: .sdrReference,
            gamut: .bt709,
            whitePoint: .d65,
            transfer: .gamma24,
            dynamicRange: .sdr,
            toneMapping: .none,
            measurementRange: .full,
            inputEncoding: .gamma24,
            implementationStatus: .native,
            supported: true,
            requiresPro: true
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as! [String: Any]
        #expect(json["family"] as? String == "sdrReference")
        #expect(json["gamut"] as? String == "bt709")
        #expect(json["whitePoint"] as? String == "d65")
        #expect(json["transfer"] as? String == "gamma2.4")
        #expect(json["dynamicRange"] as? String == "sdr")
        #expect(json["toneMapping"] as? String == "none")
        #expect(json["measurementRange"] as? String == "full")
        #expect(json["inputEncoding"] as? String == "gamma2.4")
        #expect(json["implementationStatus"] as? String == "native")
        #expect(json["supported"] as? Bool == true)
        #expect(json["requiresPro"] as? Bool == true)
    }

    @Test func getOutputPresetResultWrapsFullConfig() throws {
        let result = GetOutputColorPresetResult(
            displayId: "69734272",
            catalogRevision: "2026-06-16.1",
            preset: OutputColorPresetConfig(
                id: .deviceNative,
                label: "Device Native",
                group: "device",
                family: .device,
                gamut: .displayNative,
                whitePoint: .displayNative,
                transfer: .displayNative,
                dynamicRange: .sdr,
                toneMapping: .none,
                measurementRange: .full,
                inputEncoding: .displayCode,
                implementationStatus: .native,
                supported: true,
                requiresPro: false
            )
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as! [String: Any]
        let preset = try #require(json["preset"] as? [String: Any])
        #expect(json["displayId"] as? String == "69734272")
        #expect(json["catalogRevision"] as? String == "2026-06-16.1")
        #expect(preset["id"] as? String == "deviceNative")
        #expect(preset["inputEncoding"] as? String == "displayCode")
    }

    @Test func catalogRevisionIsOpaqueAndStableAcrossListAndGetShapes() throws {
        let revision = "opaque-catalog-token"
        let list = OutputColorPresetList(
            displayId: "69734272",
            selectedPresetId: .deviceNative,
            scope: .host,
            catalogRevision: revision,
            presets: [
                OutputColorPresetSummary(
                    id: .deviceNative,
                    label: "Device Native",
                    group: "device",
                    family: .device,
                    supported: true,
                    requiresPro: false,
                    implementationStatus: .native
                )
            ]
        )
        let get = GetOutputColorPresetResult(
            displayId: "69734272",
            catalogRevision: revision,
            preset: OutputColorPresetConfig(
                id: .deviceNative,
                label: "Device Native",
                group: "device",
                family: .device,
                gamut: .displayNative,
                whitePoint: .displayNative,
                transfer: .displayNative,
                dynamicRange: .sdr,
                toneMapping: .none,
                measurementRange: .full,
                inputEncoding: .displayCode,
                implementationStatus: .native,
                supported: true,
                requiresPro: false
            )
        )
        #expect(list.catalogRevision == get.catalogRevision)
    }

    @Test func outputPresetListDefaultsMissingCatalogRevisionToEmptyString() throws {
        let json = """
        {
          "displayId":"69734272",
          "selectedPresetId":"deviceNative",
          "scope":"host",
          "presets":[
            {
              "id":"deviceNative",
              "label":"Device Native",
              "group":"device",
              "family":"device",
              "supported":true,
              "requiresPro":false,
              "implementationStatus":"native"
            }
          ]
        }
        """

        let result = try JSONDecoder().decode(OutputColorPresetList.self, from: Data(json.utf8))

        #expect(result.catalogRevision == "")
        #expect(result.presets.first?.id == .deviceNative)
    }

    @Test func getOutputPresetResultDefaultsMissingCatalogRevisionToEmptyString() throws {
        let json = """
        {
          "displayId":"69734272",
          "preset":{
            "id":"deviceNative",
            "label":"Device Native",
            "group":"device",
            "family":"device",
            "gamut":"displayNative",
            "whitePoint":"displayNative",
            "transfer":"displayNative",
            "dynamicRange":"sdr",
            "toneMapping":"none",
            "measurementRange":"full",
            "inputEncoding":"displayCode",
            "implementationStatus":"native",
            "supported":true,
            "requiresPro":false
          }
        }
        """

        let result = try JSONDecoder().decode(GetOutputColorPresetResult.self, from: Data(json.utf8))

        #expect(result.catalogRevision == "")
        #expect(result.preset.id == .deviceNative)
    }

    @Test func outputColorPresetConfigDecodesHDRDiagnosticsAndUnknownFields() throws {
        let json = """
        {
          "id":"hdrBT2020PQ",
          "label":"BT.2020 PQ",
          "group":"hdr",
          "family":"hdrReference",
          "dynamicRange":"hdr",
          "gamut":"bt2020",
          "whitePoint":"d65",
          "transfer":"pqSt2084",
          "measurementRange":"full",
          "toneMapping":"none",
          "inputEncoding":"pqSt2084",
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

        let preset = try JSONDecoder().decode(OutputColorPresetConfig.self, from: Data(json.utf8))

        #expect(preset.id == .hdrBT2020PQ)
        #expect(preset.implementationStatus == .native)
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
