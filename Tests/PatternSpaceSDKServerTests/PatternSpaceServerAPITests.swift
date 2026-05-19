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
}
