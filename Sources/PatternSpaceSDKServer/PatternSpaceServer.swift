import Foundation
import Network
import PatternSpaceSDKCore

/// Why a registered client's lifecycle ended.
public enum ClientDisconnectReason: Sendable, Equatable {
    /// The client's socket closed (client disconnect, network failure, or protocol error).
    case closed
    /// A newer client connected and replaced this one.
    case evicted
    /// `PatternSpaceServer.stop()` closed the client.
    case serverStopped
}

/// Listener state changes reported by `PatternSpaceServer.onListenerEvent`.
public enum PatternSpaceServerListenerEvent: Sendable {
    /// The listener is bound and accepting connections on its port.
    case ready
    /// The listener could not bind or stopped unexpectedly. The server is no
    /// longer listening; call `stop()` and start a new server to retry.
    case failed(NWError)
}

/// How a server retries a bind that fails because the port is still in use.
struct ListenerBindRetryPolicy: Sendable {
    var maxRetries: Int
    var delay: DispatchTimeInterval

    /// About two seconds in total: enough for a just-cancelled listener in the
    /// same process to release its port, short enough to report a port held
    /// by another process promptly.
    static let standard = ListenerBindRetryPolicy(maxRetries: 20, delay: .milliseconds(100))
}

/// WebSocket JSON-RPC server for embedding PatternSpace protocol support.
///
/// The server advertises itself with Bonjour, accepts WebSocket connections
/// (canonically on `/patternspace`, though any resource path is accepted so
/// hostPort and Bonjour clients can connect), validates incoming requests, and
/// forwards protocol actions to a `PatternSpaceServerDelegate`.
public final class PatternSpaceServer: @unchecked Sendable {
    private let token: String?
    private let upgradeHandler: WebSocketUpgradeHandler
    private let dispatcher: JSONRPCDispatcher
    private let buildConnectionReady: (Bool) -> ConnectionReadyParams
    /// Guarded by `lock`. Replaced on each bind retry.
    private var listener: NWListener?
    /// Incremented by every `start()` and `stop()` under `lock`, so a delayed
    /// bind retry or a late listener state from an earlier run is ignored.
    private var listenerGeneration = 0
    private let listenerQueue = DispatchQueue(label: "PatternSpaceServer.listener")
    /// Internal so tests can shorten the retry window.
    var bindRetryPolicy = ListenerBindRetryPolicy.standard
    /// Every accepted socket, retained until its close is observed. Pending,
    /// registered and evicted-but-not-yet-closed connections all live here;
    /// `ClientConnection.lifecycle` distinguishes them.
    private var connections: [ObjectIdentifier: ClientConnection] = [:]
    /// True until `start()` and again after `stop()`. `NWListener.cancel()` is
    /// asynchronous, so a connection handler already in flight can still call
    /// `accept` after `stop()`; this flag fences it out.
    private var stopped = true
    /// Guards `connections`, `stopped` and each connection's `lifecycle`.
    private let lock = NSLock()
    /// Serializes every lifecycle transition together with its callbacks, so
    /// callbacks are delivered in exactly the order the transitions happened.
    private let lifecycleQueue = DispatchQueue(label: "PatternSpaceServer.lifecycle")
    private let lifecycleQueueKey = DispatchSpecificKey<Void>()

    /// Called once for each authenticated client when it becomes the active
    /// client, with the server-minted identity carried by all of its requests.
    ///
    /// Lifecycle callbacks are serialized on an internal queue and delivered
    /// in lifecycle order: when a new client replaces an existing one, the old
    /// client's `onClientDisconnected(_, .evicted)` is delivered before this
    /// callback. Callbacks triggered by `stop()` run synchronously on the thread
    /// calling `stop()`, which waits for any in-progress callback first. Keep
    /// callbacks short and non-blocking — hop to your own actor or queue — and
    /// never `DispatchQueue.main.sync` from one: `stop()` called on the main
    /// thread would deadlock.
    public var onClientConnected: ((UUID) -> Void)?

    /// Called exactly once for each client previously reported to
    /// `onClientConnected`, with the reason its lifecycle ended. Rejected
    /// (unauthenticated) sockets never produce either callback. Delivered under
    /// the same serialization and constraints as `onClientConnected`.
    public var onClientDisconnected: ((UUID, ClientDisconnectReason) -> Void)?

    /// Called when the listener becomes ready or fails. Binding is
    /// asynchronous: `start()` returning only means the bind was scheduled.
    /// A bind that fails because the port is still in use (typically a server
    /// on the same port that was just stopped) is retried for about two seconds
    /// before `.failed` is reported. Never called once `stop()` has begun.
    ///
    /// Serialized with the client lifecycle callbacks on an internal queue,
    /// under the same constraints: keep it short, hop to your own actor or
    /// queue, and never `DispatchQueue.main.sync` from it.
    public var onListenerEvent: ((PatternSpaceServerListenerEvent) -> Void)?

    /// Creates a PatternSpace protocol server.
    ///
    /// - Parameters:
    ///   - token: Optional bearer token required for WebSocket upgrades.
    ///   - delegate: Host app delegate that performs validated operations.
    ///   - connectionReady: Builds the initial device snapshot for new clients.
    ///     New clients evict any existing client before this notification is sent.
    public init(token: String?,
                delegate: any PatternSpaceServerDelegate,
                connectionReady: @escaping (Bool) -> ConnectionReadyParams) {
        self.token = token
        self.upgradeHandler = WebSocketUpgradeHandler(token: token)
        self.dispatcher = JSONRPCDispatcher(delegate: delegate)
        self.buildConnectionReady = connectionReady
        lifecycleQueue.setSpecific(key: lifecycleQueueKey, value: ())
    }

    /// Starts listening for WebSocket clients and advertising over Bonjour.
    ///
    /// Throws only for invalid listener parameters. The bind itself completes
    /// asynchronously; observe `onListenerEvent` for the outcome.
    public func start(port: UInt16 = 7878, deviceName: String) throws {
        let listener = try makeListener(port: port, deviceName: deviceName)
        var generation = 0
        onLifecycleQueue {
            lock.lock()
            stopped = false
            listenerGeneration += 1
            generation = listenerGeneration
            let superseded = self.listener
            self.listener = nil
            lock.unlock()
            superseded?.cancel()
        }
        run(listener, port: port, deviceName: deviceName, generation: generation, attempt: 0)
    }

    /// Stops the listener and closes all connected clients.
    public func stop() {
        onLifecycleQueue {
            lock.lock()
            stopped = true
            listenerGeneration += 1
            let listener = self.listener
            self.listener = nil
            let snapshot = Array(connections.values)
            connections.removeAll()
            let registered = snapshot.filter { $0.lifecycle == .registered }
            registered.forEach { $0.lifecycle = .disconnectNotified }
            lock.unlock()

            listener?.cancel()
            registered.forEach { onClientDisconnected?($0.id, .serverStopped) }
            snapshot.forEach { $0.close() }
        }
    }

    /// Broadcasts a server notification to connected clients.
    public func broadcast(_ event: PatternSpaceEvent) {
        guard let data = encodeEvent(event) else { return }
        let frame = WebSocketFrameCodec.encode(WebSocketFrame(opcode: .text, payload: data))

        lock.lock()
        let snapshot = connections.values.filter { $0.lifecycle == .registered }
        lock.unlock()

        snapshot.forEach { $0.send(frame) }
    }

    private func makeListener(port: UInt16, deviceName: String) throws -> NWListener {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw NWError.posix(.EINVAL)
        }
        let listener = try NWListener(using: parameters, on: endpointPort)
        listener.service = NWListener.Service(
            name: deviceName,
            type: "_patternspace._tcp",
            txtRecord: NWTXTRecord(serviceTXTRecord())
        )
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        return listener
    }

    /// Installs `listener` as the current listener for `generation` and starts it,
    /// unless `stop()` or a newer `start()` has superseded that generation.
    private func run(_ listener: NWListener, port: UInt16, deviceName: String,
                     generation: Int, attempt: Int) {
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener else { return }
            self.handleListenerState(state, of: listener, port: port, deviceName: deviceName,
                          generation: generation, attempt: attempt)
        }

        lock.lock()
        guard !stopped, listenerGeneration == generation else {
            lock.unlock()
            return
        }
        self.listener = listener
        lock.unlock()

        listener.start(queue: listenerQueue)
    }

    /// Runs on `listenerQueue`.
    private func handleListenerState(_ state: NWListener.State, of listener: NWListener,
                          port: UInt16, deviceName: String, generation: Int, attempt: Int) {
        guard isCurrent(listener, generation: generation) else { return }

        switch state {
        case .ready:
            deliver(.ready, generation: generation)
        case .failed(let error):
            listener.cancel()
            if case .posix(.EADDRINUSE) = error, attempt < bindRetryPolicy.maxRetries {
                listenerQueue.asyncAfter(deadline: .now() + bindRetryPolicy.delay) { [weak self] in
                    self?.retryBind(port: port, deviceName: deviceName,
                                    generation: generation, attempt: attempt + 1)
                }
                return
            }
            if clearListener(ifCurrent: listener, generation: generation) {
                deliver(.failed(error), generation: generation)
            }
        default:
            break
        }
    }

    /// Runs on `listenerQueue`.
    private func retryBind(port: UInt16, deviceName: String, generation: Int, attempt: Int) {
        lock.lock()
        let current = !stopped && listenerGeneration == generation
        lock.unlock()
        guard current else { return }

        do {
            let next = try makeListener(port: port, deviceName: deviceName)
            run(next, port: port, deviceName: deviceName, generation: generation, attempt: attempt)
        } catch let error as NWError {
            lock.lock()
            let report = !stopped && listenerGeneration == generation
            if report { self.listener = nil }
            lock.unlock()
            if report { deliver(.failed(error), generation: generation) }
        } catch {
            // `NWListener(using:on:)` only throws `NWError`.
        }
    }

    /// Delivers `event` on the lifecycle queue, which `stop()` also runs on, so
    /// an event is either delivered before `stop()` starts or not at all.
    private func deliver(_ event: PatternSpaceServerListenerEvent, generation: Int) {
        onLifecycleQueue {
            lock.lock()
            let current = !stopped && listenerGeneration == generation
            lock.unlock()
            if current { onListenerEvent?(event) }
        }
    }

    private func isCurrent(_ listener: NWListener, generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !stopped && listenerGeneration == generation && self.listener === listener
    }

    private func clearListener(ifCurrent listener: NWListener, generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped, listenerGeneration == generation, self.listener === listener else {
            return false
        }
        self.listener = nil
        return true
    }

    private func accept(_ connection: NWConnection) {
        let authenticated = token != nil
        let client = ClientConnection(
            connection: connection,
            upgradeHandler: upgradeHandler,
            dispatcher: dispatcher,
            onRejected: { endpoint in
                NSLog("PatternSpaceSDK auth failure from \(endpoint) at \(Date())")
            },
            onUpgraded: { [weak self] client in
                guard let self else { return }
                self.registerAndEvictExisting(client)
                let params = self.buildConnectionReady(authenticated)
                self.sendConnectionReady(params, to: client)
            },
            onClosed: { [weak self] client in
                self?.remove(client)
            }
        )

        // Retain the connection in `connections` until its close is observed.
        // Without this, `client` has no strong owner once `accept` returns, so
        // it deallocates before the WebSocket upgrade is processed and the
        // server never responds to the handshake.
        lock.lock()
        guard !stopped else {
            lock.unlock()
            connection.cancel()
            return
        }
        connections[ObjectIdentifier(client)] = client
        lock.unlock()

        client.start()
    }

    /// Replaces the active client in one serialized lifecycle operation:
    /// evicted clients are notified (and marked notified) first, then the new
    /// client is registered and announced, and only then are old sockets closed,
    /// so their late `remove` cannot notify a second time.
    private func registerAndEvictExisting(_ client: ClientConnection) {
        onLifecycleQueue {
            lock.lock()
            guard canRegister(client) else {
                // Closed or stopped before the upgrade was registered.
                lock.unlock()
                return
            }
            let evicted = connections.values.filter { $0.lifecycle == .registered }
            evicted.forEach { $0.lifecycle = .disconnectNotified }
            lock.unlock()

            evicted.forEach { onClientDisconnected?($0.id, .evicted) }

            // An eviction callback may have called `stop()` (or the new socket
            // may have closed); in that case the replacement never registers.
            lock.lock()
            let register = canRegister(client)
            if register { client.lifecycle = .registered }
            lock.unlock()
            if register { onClientConnected?(client.id) }

            evicted.forEach { $0.close() }
        }
    }

    /// Must be called with `lock` held.
    private func canRegister(_ client: ClientConnection) -> Bool {
        !stopped
            && client.lifecycle == .pending
            && connections[ObjectIdentifier(client)] != nil
    }

    private func remove(_ client: ClientConnection) {
        onLifecycleQueue {
            lock.lock()
            connections.removeValue(forKey: ObjectIdentifier(client))
            let notify = client.lifecycle == .registered
            if notify { client.lifecycle = .disconnectNotified }
            lock.unlock()

            if notify { onClientDisconnected?(client.id, .closed) }
        }
    }

    /// Runs `work` synchronously on the lifecycle queue, inline when already on
    /// it (e.g. a lifecycle callback that calls `stop()`).
    private func onLifecycleQueue(_ work: () -> Void) {
        if DispatchQueue.getSpecific(key: lifecycleQueueKey) != nil {
            work()
        } else {
            lifecycleQueue.sync(execute: work)
        }
    }

    private func sendConnectionReady(_ params: ConnectionReadyParams, to client: ClientConnection) {
        let notification = JSONRPCNotification(method: "connectionReady", params: params)
        guard let data = try? JSONEncoder().encode(notification) else { return }
        let frame = WebSocketFrameCodec.encode(WebSocketFrame(opcode: .text, payload: data))
        client.send(frame)
    }

    private func encodeEvent(_ event: PatternSpaceEvent) -> Data? {
        switch event {
        case .connectionReady(let params):
            return try? JSONEncoder().encode(JSONRPCNotification(method: "connectionReady", params: params))
        case .patternChanged(let patternId, let source):
            struct Params: Encodable { let patternId: String?; let source: String }
            return try? JSONEncoder().encode(JSONRPCNotification(
                method: "pattern.changed",
                params: Params(patternId: patternId, source: source)
            ))
        case .deviceStatusChanged(let snapshot):
            return try? JSONEncoder().encode(JSONRPCNotification(method: "device.statusChanged", params: snapshot))
        case .connectionFailed:
            return nil
        case .displayChanged(let result):
            return try? JSONEncoder().encode(JSONRPCNotification(method: "display.changed", params: result))
        }
    }

    private func serviceTXTRecord() -> [String: String] {
        [
            "protocolVersion": PatternSpaceProtocolMetadata.protocolVersion,
            "authRequired": token == nil ? "false" : "true"
        ]
    }

    #if DEBUG
    /// Test-only entry point simulating a listener connection handler that
    /// fires after `stop()` (NWListener cancellation is asynchronous).
    public func acceptForTest(_ connection: NWConnection) {
        accept(connection)
    }

    /// Test-only count of sockets the server still tracks (pending, active, or
    /// evicted but not yet observed closed).
    public func openConnectionCountForTest() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return connections.count
    }

    /// Test-only helper that encodes an event as a JSON-RPC notification payload.
    public func encodedEventForTest(_ event: PatternSpaceEvent) throws -> Data {
        guard let data = encodeEvent(event) else {
            throw PSDispatchError(.internalError, message: "failed to encode notification")
        }
        return data
    }

    /// Test-only helper exposing the Bonjour TXT payload without starting a listener.
    public func serviceTXTRecordForTest() -> [String: String] {
        serviceTXTRecord()
    }
    #endif
}
