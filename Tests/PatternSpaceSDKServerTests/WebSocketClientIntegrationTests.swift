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

    @Test func clientOutputCallsCarryServerAssignedIdentity() async throws {
        let port: UInt16 = 18_788
        let delegate = MockDelegate()
        let server = makeServer(delegate: delegate)
        try server.start(port: port, deviceName: "PatternSpaceSDK output test")
        defer { server.stop() }

        let client = makeClient(port: port, token: "test-token")
        client.connect()
        defer { client.disconnect() }

        let blanked = try await withinTwoSeconds(client) { try await client.output.blank() }
        let resumed = try await withinTwoSeconds(client) { try await client.output.resume() }
        _ = try await withinTwoSeconds(client) { try await client.pattern.clear() }

        #expect(blanked == delegate.outputStatus)
        #expect(resumed == delegate.outputStatus)
        let blank = try #require(delegate.blankContexts.first)
        #expect(delegate.blankContexts.count == 1)
        #expect(delegate.resumeContexts == [blank])
        #expect(delegate.clearContexts == [blank])
    }

    @Test func unauthenticatedClientNeverReachesOutputDelegate() async throws {
        let port: UInt16 = 18_789
        let delegate = MockDelegate()
        let server = makeServer(delegate: delegate)
        try server.start(port: port, deviceName: "PatternSpaceSDK auth test")
        defer { server.stop() }

        let client = makeClient(port: port, token: "wrong-token")
        client.connect()
        defer { client.disconnect() }

        await #expect(throws: (any Error).self) {
            _ = try await withinTwoSeconds(client) { try await client.output.blank() }
        }
        #expect(delegate.blankContexts.isEmpty)
    }

    private func makeServer(delegate: MockDelegate) -> PatternSpaceServer {
        PatternSpaceServer(token: "test-token", delegate: delegate) { authenticated in
            ConnectionReadyParams(
                protocolVersion: PatternSpaceProtocolMetadata.protocolVersion,
                name: "Test PatternSpace", resolution: Resolution(width: 1920, height: 1080),
                colorFormat: "RGB", bitDepth: 10, hdrMode: "SDR", refreshRate: 60,
                outputRange: "full", currentPatternId: nil, sourceActive: true,
                authenticated: authenticated
            )
        }
    }

    private func makeClient(port: UInt16, token: String) -> PatternSpaceClient {
        let endpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        return PatternSpaceClient(
            service: PatternSpaceService(name: "test", endpoint: endpoint, port: port),
            token: token
        )
    }

    private func withinTwoSeconds<T: Sendable>(
        _ client: PatternSpaceClient,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                client.disconnect()
                throw WebSocketClientTestError.timedOut
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else {
                throw WebSocketClientTestError.timedOut
            }
            return value
        }
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
