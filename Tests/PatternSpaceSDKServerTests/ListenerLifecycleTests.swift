import Foundation
import Network
import Testing
@testable import PatternSpaceSDKServer
import PatternSpaceSDKCore

@Suite(.serialized) struct ListenerLifecycleTests {
    /// Regression: stopping a server and immediately starting another on the
    /// same port used to fail silently with EADDRINUSE, leaving nothing bound.
    @Test func restartOnSamePortBecomesReady() async throws {
        let port: UInt16 = 18_811
        let first = makeServer()
        let firstEvents = events(of: first)
        try first.start(port: port, deviceName: "PatternSpaceSDK restart test")
        #expect(try await next(firstEvents).isReady)

        first.stop()
        let second = makeServer()
        let secondEvents = events(of: second)
        try second.start(port: port, deviceName: "PatternSpaceSDK restart test")
        defer { second.stop() }

        #expect(try await next(secondEvents).isReady)
        #expect(await tcpConnects(port: port))
    }

    @Test func portHeldElsewhereReportsFailure() async throws {
        let port: UInt16 = 18_812
        let blocker = try await holdPort(port)
        defer { blocker.cancel() }

        let server = makeServer()
        server.bindRetryPolicy = ListenerBindRetryPolicy(maxRetries: 2, delay: .milliseconds(10))
        let stream = events(of: server)
        try server.start(port: port, deviceName: "PatternSpaceSDK busy port test")
        defer { server.stop() }

        guard case .failed(let error) = try await next(stream) else {
            Issue.record("expected the listener to fail")
            return
        }
        #expect(error == .posix(.EADDRINUSE))
    }

    @Test func stopDuringBindRetryReportsNothing() async throws {
        let port: UInt16 = 18_813
        let blocker = try await holdPort(port)

        let server = makeServer()
        server.bindRetryPolicy = ListenerBindRetryPolicy(maxRetries: 50, delay: .milliseconds(20))
        let recorder = EventRecorder()
        server.onListenerEvent = { recorder.append($0) }
        try server.start(port: port, deviceName: "PatternSpaceSDK stop retry test")

        try await Task.sleep(for: .milliseconds(100))
        server.stop()
        blocker.cancel()
        try await Task.sleep(for: .milliseconds(300))

        #expect(recorder.count == 0)
        #expect(await !tcpConnects(port: port))
    }

    // MARK: - Helpers

    private func makeServer() -> PatternSpaceServer {
        PatternSpaceServer(token: "test-token", delegate: MockDelegate()) { authenticated in
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
    }

    private func events(of server: PatternSpaceServer) -> AsyncStream<PatternSpaceServerListenerEvent> {
        let (stream, continuation) = AsyncStream<PatternSpaceServerListenerEvent>.makeStream()
        server.onListenerEvent = { continuation.yield($0) }
        return stream
    }

    private func next(_ stream: AsyncStream<PatternSpaceServerListenerEvent>) async throws
        -> PatternSpaceServerListenerEvent {
        try await withThrowingTaskGroup(of: PatternSpaceServerListenerEvent?.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(3))
                return nil
            }
            defer { group.cancelAll() }
            guard let event = try await group.next() ?? nil else {
                throw ListenerTestError.timedOut
            }
            return event
        }
    }

    /// Binds `port` with a plain listener so the server under test cannot.
    private func holdPort(_ port: UInt16) async throws -> NWListener {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { $0.cancel() }
        let (ready, continuation) = AsyncStream<Bool>.makeStream()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: continuation.yield(true)
            case .failed: continuation.yield(false)
            default: break
            }
        }
        listener.start(queue: .global())
        var iterator = ready.makeAsyncIterator()
        guard await iterator.next() == true else { throw ListenerTestError.blockerFailed }
        return listener
    }

    private func tcpConnects(port: UInt16) async -> Bool {
        let connection = NWConnection(
            host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready: continuation.yield(true)
            case .failed, .waiting: continuation.yield(false)
            default: break
            }
        }
        connection.start(queue: .global())
        defer { connection.cancel() }
        var iterator = stream.makeAsyncIterator()
        return await iterator.next() ?? false
    }
}

private enum ListenerTestError: Error {
    case timedOut
    case blockerFailed
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [PatternSpaceServerListenerEvent] = []

    func append(_ event: PatternSpaceServerListenerEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }
}

private extension PatternSpaceServerListenerEvent {
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}
