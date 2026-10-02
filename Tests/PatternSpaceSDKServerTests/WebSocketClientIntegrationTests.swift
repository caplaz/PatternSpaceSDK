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

    @Test func evictionAndShutdownNotifyEachClientExactlyOnceInOrder() async throws {
        let port: UInt16 = 18_790
        let server = makeServer(delegate: MockDelegate())
        let recorder = LifecycleRecorder(server)
        try server.start(port: port, deviceName: "PatternSpaceSDK lifecycle test")
        defer { server.stop() }

        let clientA = makeClient(port: port, token: "test-token")
        clientA.connect()
        defer { clientA.disconnect() }
        try await poll { recorder.events == ["connected:A"] }

        let clientB = makeClient(port: port, token: "test-token")
        clientB.connect()
        defer { clientB.disconnect() }
        try await poll { recorder.events.count == 3 }

        // A's socket closes only after B is registered; that late close must
        // not produce a second disconnect for A (nor suppress B's lifecycle).
        clientA.disconnect()
        try await poll { server.openConnectionCountForTest() == 1 }

        server.stop()
        #expect(recorder.events == [
            "connected:A", "disconnected:A:evicted",
            "connected:B", "disconnected:B:serverStopped"
        ])
    }

    @Test func ordinaryCloseAfterEvictionNotifiesClosed() async throws {
        let port: UInt16 = 18_791
        let server = makeServer(delegate: MockDelegate())
        let recorder = LifecycleRecorder(server)
        try server.start(port: port, deviceName: "PatternSpaceSDK close test")
        defer { server.stop() }

        let clientA = makeClient(port: port, token: "test-token")
        clientA.connect()
        defer { clientA.disconnect() }
        try await poll { recorder.events == ["connected:A"] }

        let clientB = makeClient(port: port, token: "test-token")
        clientB.connect()
        try await poll { recorder.events.count == 3 }

        clientB.disconnect()
        try await poll { recorder.events.count == 4 }
        clientA.disconnect()
        try await poll { server.openConnectionCountForTest() == 0 }

        #expect(recorder.events == [
            "connected:A", "disconnected:A:evicted",
            "connected:B", "disconnected:B:closed"
        ])
    }

    @Test func ordinaryCloseNotifiesClosedWhileOtherSocketsRemainOpen() async throws {
        let port: UInt16 = 18_792
        let server = makeServer(delegate: MockDelegate())
        let recorder = LifecycleRecorder(server)
        try server.start(port: port, deviceName: "PatternSpaceSDK close-with-others test")
        defer { server.stop() }

        let clientA = makeClient(port: port, token: "test-token")
        clientA.connect()
        try await poll { recorder.events == ["connected:A"] }

        // A second socket that is still open (never registered) must not
        // suppress A's disconnect notification.
        let other = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        other.start(queue: .global())
        defer { other.cancel() }
        try await poll { server.openConnectionCountForTest() == 2 }

        clientA.disconnect()
        try await poll { recorder.events.count == 2 }
        #expect(recorder.events == ["connected:A", "disconnected:A:closed"])
        #expect(server.openConnectionCountForTest() == 1)
    }

    @Test func unauthenticatedRejectionProducesNoLifecycleCallbacks() async throws {
        let port: UInt16 = 18_793
        let server = makeServer(delegate: MockDelegate())
        let recorder = LifecycleRecorder(server)
        try server.start(port: port, deviceName: "PatternSpaceSDK rejection test")
        defer { server.stop() }

        let client = makeClient(port: port, token: "wrong-token")
        client.connect()
        await #expect(throws: (any Error).self) {
            _ = try await withinTwoSeconds(client) { try await client.device.status() }
        }
        client.disconnect()
        try await poll { server.openConnectionCountForTest() == 0 }
        server.stop()

        #expect(recorder.events.isEmpty)
    }

    /// Polls `condition` every 10 ms until it holds, failing after 3 seconds.
    private func poll(
        _ condition: @escaping @Sendable () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("condition not met within 3 seconds", sourceLocation: sourceLocation)
                throw WebSocketClientTestError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
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

/// Records server lifecycle callbacks, mapping each real client UUID to a
/// deterministic label ("A", "B", ...) in order of first appearance.
private final class LifecycleRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var labels: [UUID: String] = [:]
    private var recorded: [String] = []

    init(_ server: PatternSpaceServer) {
        server.onClientConnected = { [self] id in
            append { "connected:\(label(for: id))" }
        }
        server.onClientDisconnected = { [self] id, reason in
            append { "disconnected:\(label(for: id)):\(reason)" }
        }
    }

    var events: [String] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    private func append(_ makeEvent: () -> String) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(makeEvent())
    }

    /// Must be called with `lock` held.
    private func label(for id: UUID) -> String {
        if let label = labels[id] { return label }
        let label = String(UnicodeScalar(UInt8(65 + labels.count)))
        labels[id] = label
        return label
    }
}
