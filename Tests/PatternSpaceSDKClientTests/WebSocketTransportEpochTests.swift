import Foundation
import Network
import Testing
@testable import PatternSpaceSDKClient
import PatternSpaceSDKCore

/// Delayed old-reader regressions: a receive completion from a replaced socket
/// (held via the transport's receive-completion seam) must never deliver a
/// message, report a disconnect, or fail the newer socket's pending RPCs.
/// Every test runs against both the URLSession (explicit host) and the
/// Network.framework (non-host endpoint) paths.
@Suite(.serialized) struct WebSocketTransportEpochTests {
    enum TransportPath: CaseIterable, Sendable { case urlSession, native }

    // MARK: - Transport

    @Test(arguments: TransportPath.allCases)
    func heldOldMessageIsDroppedAfterReplacement(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let gate = ReceiveGate()
        let transport = WebSocketTransport(receiveCompletionHook: gate.hook)
        let recorder = TransportRecorder(transport)
        defer { transport.disconnect() }

        transport.connect(to: server.endpoint(path), token: nil)
        try await poll { server.connectionCount == 1 }
        gate.holding = true
        server.send("a-late", to: 0)
        try await poll { gate.heldCount >= 1 }
        gate.holding = false

        transport.connect(to: server.endpoint(path), token: nil)
        try await poll { server.connectionCount == 2 }
        server.send("b-1", to: 1)
        try await poll { recorder.messages == ["b-1"] }
        let disconnectsBeforeRelease = recorder.disconnects

        gate.releaseAll()
        try await settle(transport)
        #expect(recorder.messages == ["b-1"])
        #expect(recorder.disconnects == disconnectsBeforeRelease)
    }

    @Test(arguments: TransportPath.allCases)
    func heldOldErrorIsDroppedAfterReplacement(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let gate = ReceiveGate()
        let transport = WebSocketTransport(receiveCompletionHook: gate.hook)
        let recorder = TransportRecorder(transport)
        defer { transport.disconnect() }

        transport.connect(to: server.endpoint(path), token: nil)
        try await poll { server.connectionCount == 1 }
        gate.holding = true
        server.close(0)
        try await poll { gate.heldCount >= 1 }
        gate.holding = false

        transport.connect(to: server.endpoint(path), token: nil)
        try await poll { server.connectionCount == 2 }
        server.send("b-1", to: 1)
        try await poll { recorder.messages == ["b-1"] }
        let disconnectsBeforeRelease = recorder.disconnects

        gate.releaseAll()
        try await settle(transport)
        server.send("b-2", to: 1)
        try await poll { recorder.messages == ["b-1", "b-2"] }
        #expect(recorder.disconnects == disconnectsBeforeRelease)
    }

    @Test(arguments: TransportPath.allCases)
    func messagesArriveInOrderWithoutReconnect(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let transport = WebSocketTransport()
        let recorder = TransportRecorder(transport)
        defer { transport.disconnect() }

        transport.connect(to: server.endpoint(path), token: nil)
        try await poll { server.connectionCount == 1 }
        let expected = (0..<100).map { "m\($0)" }
        expected.forEach { server.send($0, to: 0) }
        try await poll { recorder.messages.count == expected.count }
        #expect(recorder.messages == expected)
        #expect(recorder.disconnects == 0)
    }

    // MARK: - Client

    @Test(arguments: TransportPath.allCases)
    func lateOldEventNeverFollowsNewConnection(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let gate = ReceiveGate()
        let transport = WebSocketTransport(receiveCompletionHook: gate.hook)
        let client = makeClient(server, path, transport: transport)
        let events = EventRecorder(client)
        defer { client.disconnect() }

        client.connect()
        try await poll { events.markers == ["ready-0"] }
        gate.holding = true
        server.send(Self.patternChanged("a-late"), to: 0)
        try await poll { gate.heldCount >= 1 }
        gate.holding = false

        client.connect()
        try await poll { events.markers == ["ready-0", "ready-1"] }
        let rpc = Task { try await client.pattern.clear() }
        try await poll { server.requestIDs(on: 1).count == 1 }

        gate.releaseAll()
        try await settle(transport)
        server.reply(to: 1)
        try await withTimeout { try await rpc.value }
        #expect(events.markers == ["ready-0", "ready-1"])
        #expect(events.failures == 0)
        #expect(server.connectionCount == 2)
    }

    @Test(arguments: TransportPath.allCases)
    func lateOldDisconnectCannotFailNewRPCOrReconnect(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let gate = ReceiveGate()
        let transport = WebSocketTransport(receiveCompletionHook: gate.hook)
        let client = makeClient(server, path, transport: transport)
        let events = EventRecorder(client)
        defer { client.disconnect() }

        client.connect()
        try await poll { events.markers == ["ready-0"] }
        gate.holding = true
        server.close(0)
        try await poll { gate.heldCount >= 1 }
        gate.holding = false

        client.connect()
        try await poll { events.markers == ["ready-0", "ready-1"] }
        let failuresBeforeRelease = events.failures
        let rpc = Task { try await client.pattern.clear() }
        try await poll { server.requestIDs(on: 1).count == 1 }

        gate.releaseAll()
        try await settle(transport)
        try await Task.sleep(for: .milliseconds(400))
        server.reply(to: 1)
        try await withTimeout { try await rpc.value }
        #expect(events.failures == failuresBeforeRelease)
        #expect(server.connectionCount == 2)
    }

    @Test(arguments: TransportPath.allCases)
    func replacementFailsOnlyOldGenerationRPCs(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let client = makeClient(server, path)
        let events = EventRecorder(client)
        defer { client.disconnect() }

        client.connect()
        try await poll { events.markers == ["ready-0"] }
        let oldRPC = Task { try await client.pattern.clear() }
        try await poll { server.requestIDs(on: 0).count == 1 }

        client.connect()
        try await poll { events.markers == ["ready-0", "ready-1"] }
        await #expect(throws: PatternSpaceClientError.self) {
            try await withTimeout { try await oldRPC.value }
        }
        let newRPC = Task { try await client.pattern.clear() }
        try await poll { server.requestIDs(on: 1).count == 1 }
        server.reply(to: 1)
        try await withTimeout { try await newRPC.value }
        #expect(events.failures == 0)
    }

    @Test(arguments: TransportPath.allCases)
    func scheduledReconnectCannotReplaceManualConnection(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let client = makeClient(server, path, reconnectDelay: 0.3)
        let events = EventRecorder(client)
        defer { client.disconnect() }

        client.connect()
        try await poll { events.markers == ["ready-0"] }
        server.close(0)
        try await poll { events.failures == 1 }

        client.connect()
        try await poll { events.markers == ["ready-0", "ready-1"] }
        let rpc = Task { try await client.pattern.clear() }
        try await poll { server.requestIDs(on: 1).count == 1 }
        try await Task.sleep(for: .milliseconds(600))
        server.reply(to: 1)
        try await withTimeout { try await rpc.value }
        #expect(server.connectionCount == 2)
        #expect(events.failures == 1)
    }

    @Test(arguments: TransportPath.allCases)
    func repeatedFailuresReconnectAutomatically(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let client = makeClient(server, path, reconnectDelay: 0.05)
        let events = EventRecorder(client)
        defer { client.disconnect() }

        client.connect()
        for index in 0..<3 {
            try await poll { events.markers.count == index + 1 }
            server.close(index)
        }
        try await poll { events.markers == ["ready-0", "ready-1", "ready-2", "ready-3"] }
        let rpc = Task { try await client.pattern.clear() }
        try await poll { server.requestIDs(on: 3).count == 1 }
        server.reply(to: 3)
        try await withTimeout { try await rpc.value }
        #expect(events.failures == 3)
    }

    @Test(arguments: TransportPath.allCases)
    func shutdownFailsPendingAndCancelsScheduledReconnect(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let client = makeClient(server, path, reconnectDelay: 0.2)
        let events = EventRecorder(client)

        client.connect()
        try await poll { events.markers == ["ready-0"] }
        server.close(0)
        try await poll { events.failures == 1 }
        client.disconnect()
        try await Task.sleep(for: .milliseconds(500))
        #expect(server.connectionCount == 1)

        let reconnecting = makeClient(server, path, reconnectDelay: 0.2)
        let reconnectingEvents = EventRecorder(reconnecting)
        reconnecting.connect()
        try await poll { reconnectingEvents.markers == ["ready-1"] }
        let rpc = Task { try await reconnecting.pattern.clear() }
        try await poll { server.requestIDs(on: 1).count == 1 }
        reconnecting.disconnect()
        await #expect(throws: PatternSpaceClientError.self) {
            try await withTimeout { try await rpc.value }
        }
    }

    @Test(arguments: TransportPath.allCases)
    func pendingCallFailsWhenClientIsReleasedAfterDisconnect(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        var client: PatternSpaceClient? = makeClient(server, path)
        let events = EventRecorder(try #require(client))
        let pattern = try #require(client).pattern

        client?.connect()
        try await poll { events.markers == ["ready-0"] }
        let rpc = Task { try await pattern.clear() }
        try await poll { server.requestIDs(on: 0).count == 1 }

        weak let released = client
        client?.disconnect()
        client = nil
        #expect(released == nil)
        await #expect(throws: PatternSpaceClientError.self) {
            try await withTimeout { try await rpc.value }
        }
    }

    @Test(arguments: TransportPath.allCases)
    func eventsPreserveServerOrder(path: TransportPath) async throws {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let client = makeClient(server, path)
        let events = EventRecorder(client)
        defer { client.disconnect() }

        client.connect()
        try await poll { events.markers == ["ready-0"] }
        let expected = (0..<50).map { "e\($0)" }
        expected.forEach { server.send(Self.patternChanged($0), to: 0) }
        try await poll { events.markers.count == expected.count + 1 }
        #expect(events.markers == ["ready-0"] + expected)
    }

    // MARK: - Helpers

    static func patternChanged(_ marker: String) -> String {
        #"{"jsonrpc":"2.0","method":"pattern.changed","params":{"patternId":"\#(marker)","source":"test"}}"#
    }

    private func makeClient(
        _ server: TestWebSocketServer,
        _ path: TransportPath,
        transport: WebSocketTransport = WebSocketTransport(),
        reconnectDelay: TimeInterval = 0.2
    ) -> PatternSpaceClient {
        PatternSpaceClient(
            service: PatternSpaceService(name: "test", endpoint: server.endpoint(path), port: server.port),
            token: nil,
            transport: transport,
            reconnectDelay: reconnectDelay
        )
    }

    /// Waits until every completion already handed to the transport has been
    /// processed, plus a margin for any unserialized delivery.
    private func settle(_ transport: WebSocketTransport) async throws {
        transport.flushForTesting()
        try await Task.sleep(for: .milliseconds(150))
        transport.flushForTesting()
    }

    private func poll(
        _ condition: @escaping @Sendable () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("condition not met within 3 seconds", sourceLocation: sourceLocation)
                throw EpochTestError.timedOut
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Races `operation` against a 2-second deadline without awaiting the
    /// loser, so a never-resumed RPC fails the test instead of hanging it.
    private func withTimeout<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            Task { once.resume(with: await Result(catching: operation)) }
            Task {
                try? await Task.sleep(for: .seconds(2))
                once.resume(with: .failure(EpochTestError.timedOut))
            }
        }
    }
}
