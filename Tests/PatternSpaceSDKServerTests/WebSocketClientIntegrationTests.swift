import Foundation
import Network
import Testing
@testable import PatternSpaceSDKServer
import PatternSpaceSDKClient
import PatternSpaceSDKCore

@Suite(.serialized) struct WebSocketClientIntegrationTests {
    @Test func clientReceivesStatusFromSDKServer() async throws {
        let port: UInt16 = 18_787
        let delegate = MockDelegate()
        let server = PatternSpaceServer(
            token: "test-token",
            delegate: delegate,
            connectionReady: { authenticated in
                ConnectionReadyParams(
                    protocolVersion: PatternSpaceProtocolMetadata.protocolVersion,
                    name: "Test PatternSpace",
                    resolution: Resolution(width: 1920, height: 1080),
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
        )
        try server.start(port: port, deviceName: "PatternSpaceSDK test")
        defer { server.stop() }

        let endpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: try #require(NWEndpoint.Port(rawValue: port))
        )
        let client = PatternSpaceClient(
            service: PatternSpaceService(name: "test", endpoint: endpoint, port: port),
            token: "test-token"
        )
        client.connect()
        defer { client.disconnect() }

        let status = try await statusWithinTwoSeconds(from: client)
        #expect(status.sourceActive)
    }

    private func statusWithinTwoSeconds(from client: PatternSpaceClient) async throws -> DeviceStatus {
        try await withThrowingTaskGroup(of: DeviceStatus.self) { group in
            group.addTask { try await client.device.status() }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                client.disconnect()
                throw WebSocketClientTestError.timedOut
            }
            defer { group.cancelAll() }
            guard let status = try await group.next() else {
                throw WebSocketClientTestError.timedOut
            }
            return status
        }
    }
}

private enum WebSocketClientTestError: Error {
    case timedOut
}
