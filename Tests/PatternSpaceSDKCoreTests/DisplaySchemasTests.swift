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
    }
}
