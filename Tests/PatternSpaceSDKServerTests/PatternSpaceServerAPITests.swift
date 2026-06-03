import Foundation
import Testing
import PatternSpaceSDKCore
@testable import PatternSpaceSDKServer

@Suite struct PatternSpaceServerAPITests {
    @Test func connectionReadyBuilderDoesNotExposeClientCount() {
        let delegate = MockDelegate()
        let server = PatternSpaceServer(token: nil, delegate: delegate) { authenticated in
            ConnectionReadyParams(
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
                authenticated: authenticated
            )
        }

        withExtendedLifetime(server) {}
    }

    @Test func displayChangedNotificationUsesDisplayListPayload() throws {
        let result = DisplayListResult(
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
                    maximumPotentialEDR: 4,
                    maximumCurrentEDR: 2,
                    peakWhite: 4,
                    effectivePeakWhite: 2,
                    peakWhiteRange: PeakWhiteRange(maximum: 4),
                    supportsPeakWhiteControl: true
                )
            ]
        )

        let delegate = MockDelegate()
        let server = PatternSpaceServer(token: nil, delegate: delegate) { authenticated in
            ConnectionReadyParams(
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
                authenticated: authenticated
            )
        }
        let data = try server.encodedEventForTest(.displayChanged(result))
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)

        #expect(obj.object?["method"] == JSONValue.string("display.changed"))
        #expect(obj.object?["params"]?.object?["selectedDisplayId"] == JSONValue.string("69734272"))
    }
}
