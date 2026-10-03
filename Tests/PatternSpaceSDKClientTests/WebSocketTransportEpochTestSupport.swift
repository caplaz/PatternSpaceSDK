import Foundation
import Network
@testable import PatternSpaceSDKClient

// Support types for WebSocketTransportEpochTests.

enum EpochTestError: Error { case timedOut }

final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }

    func resume(with result: Result<T, Error>) {
        let pending = lock.withLock { () -> CheckedContinuation<T, Error>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(with: result)
    }
}

extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}

/// Holds raw receive completions while `holding` is set; passes others through.
final class ReceiveGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isHolding = false
    private var held: [@Sendable () -> Void] = []

    var holding: Bool {
        get { lock.withLock { isHolding } }
        set { lock.withLock { isHolding = newValue } }
    }

    var heldCount: Int { lock.withLock { held.count } }

    var hook: WebSocketTransport.ReceiveCompletionHook {
        { [self] _, deliver in
            let passThrough = lock.withLock { () -> Bool in
                guard isHolding else { return true }
                held.append(deliver)
                return false
            }
            if passThrough { deliver() }
        }
    }

    func releaseAll() {
        let pending = lock.withLock { () -> [@Sendable () -> Void] in
            defer { held.removeAll() }
            return held
        }
        pending.forEach { $0() }
    }
}

final class TransportRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMessages: [String] = []
    private var recordedDisconnects = 0

    init(_ transport: WebSocketTransport) {
        transport.onMessage = { [self] data in
            let text = String(decoding: data, as: UTF8.self)
            guard !text.hasPrefix("{") else { return } // skip the server's ready marker
            lock.withLock { recordedMessages.append(text) }
        }
        transport.onDisconnect = { [self] _ in
            lock.withLock { recordedDisconnects += 1 }
        }
    }

    var messages: [String] { lock.withLock { recordedMessages } }
    var disconnects: Int { lock.withLock { recordedDisconnects } }
}

/// Collects `patternChanged` markers and `connectionFailed` counts in stream order.
final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMarkers: [String] = []
    private var recordedFailures = 0
    private var task: Task<Void, Never>?

    init(_ client: PatternSpaceClient) {
        let stream = client.events
        task = Task { [self] in
            for await event in stream {
                switch event {
                case .patternChanged(let id, _):
                    lock.withLock { recordedMarkers.append(id ?? "") }
                case .connectionFailed:
                    lock.withLock { recordedFailures += 1 }
                default:
                    break
                }
            }
        }
    }

    deinit { task?.cancel() }

    var markers: [String] { lock.withLock { recordedMarkers } }
    var failures: Int { lock.withLock { recordedFailures } }
}

/// Loopback WebSocket server built on NWListener. Each accepted connection
/// gets an index in accept order and is greeted with a `ready-<index>` marker.
final class TestWebSocketServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "TestWebSocketServer")
    private let lock = NSLock()
    private var connections: [NWConnection] = []
    private var requests: [Int: [String]] = [:]
    let port: UInt16

    private init(listener: NWListener, port: UInt16) {
        self.listener = listener
        self.port = port
    }

    static func start() async throws -> TestWebSocketServer {
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        let listener = try NWListener(using: parameters, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        let queue = DispatchQueue(label: "TestWebSocketServer.listener")
        var server: TestWebSocketServer?
        listener.newConnectionHandler = { connection in server?.accept(connection) }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 3) == .success, let port = listener.port?.rawValue else {
            listener.cancel()
            throw EpochTestError.timedOut
        }
        let created = TestWebSocketServer(listener: listener, port: port)
        queue.sync { server = created }
        return created
    }

    func endpoint(_ path: WebSocketTransportEpochTests.TransportPath) -> NWEndpoint {
        switch path {
        case .urlSession:
            return .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        case .native:
            return .url(URL(string: "ws://127.0.0.1:\(port)/patternspace")!)
        }
    }

    var connectionCount: Int { lock.withLock { connections.count } }

    func requestIDs(on index: Int) -> [String] { lock.withLock { requests[index] ?? [] } }

    func send(_ text: String, to index: Int) {
        let connection = lock.withLock { connections[index] }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: Data(text.utf8), contentContext: context, isComplete: true, completion: .idempotent)
    }

    /// Answers every request received on `index` with a null result.
    func reply(to index: Int) {
        for id in requestIDs(on: index) {
            send(#"{"jsonrpc":"2.0","id":"\#(id)","result":null}"#, to: index)
        }
    }

    func close(_ index: Int) {
        lock.withLock { connections[index] }.cancel()
    }

    func stop() {
        listener.cancel()
        lock.withLock { connections }.forEach { $0.cancel() }
    }

    private func accept(_ connection: NWConnection) {
        let index = lock.withLock { () -> Int in
            connections.append(connection)
            return connections.count - 1
        }
        connection.stateUpdateHandler = { [weak self] state in
            guard case .ready = state, let self else { return }
            self.send(WebSocketTransportEpochTests.patternChanged("ready-\(index)"), to: index)
            self.receive(on: connection, index: index)
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection, index: Int) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, error == nil else { return }
            if let data,
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = object["id"] as? String {
                self.lock.withLock { self.requests[index, default: []].append(id) }
            }
            if data != nil { self.receive(on: connection, index: index) }
        }
    }
}
