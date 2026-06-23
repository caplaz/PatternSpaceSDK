import Foundation
import Network
import PatternSpaceSDKCore

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
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: ClientConnection] = [:]
    private var pendingClients: [ObjectIdentifier: ClientConnection] = [:]
    private let lock = NSLock()

    /// Called on a background queue when the last active (upgraded) client disconnects.
    public var onClientDisconnected: (() -> Void)?

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
    }

    /// Starts listening for WebSocket clients and advertising over Bonjour.
    public func start(port: UInt16 = 7878, deviceName: String) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        listener.service = NWListener.Service(
            name: deviceName,
            type: "_patternspace._tcp",
            txtRecord: NWTXTRecord(serviceTXTRecord())
        )

        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: .global(qos: .utility))
        self.listener = listener
    }

    /// Stops the listener and closes all connected clients.
    public func stop() {
        listener?.cancel()
        listener = nil

        lock.lock()
        let snapshot = Array(clients.values) + Array(pendingClients.values)
        clients.removeAll()
        pendingClients.removeAll()
        lock.unlock()

        snapshot.forEach { $0.close() }
    }

    /// Broadcasts a server notification to connected clients.
    public func broadcast(_ event: PatternSpaceEvent) {
        guard let data = encodeEvent(event) else { return }
        let frame = WebSocketFrameCodec.encode(WebSocketFrame(opcode: .text, payload: data))

        lock.lock()
        let snapshot = Array(clients.values)
        lock.unlock()

        snapshot.forEach { $0.send(frame) }
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
                let evicted = self.registerAndEvictExisting(client)
                evicted.forEach { $0.close() }
                let params = self.buildConnectionReady(authenticated)
                self.sendConnectionReady(params, to: client)
            },
            onClosed: { [weak self] client in
                self?.remove(client)
            }
        )

        // Retain the connection until it either upgrades (moves to `clients`)
        // or closes. Without this, `client` has no strong owner once `accept`
        // returns, so it deallocates before the WebSocket upgrade is processed
        // and the server never responds to the handshake.
        lock.lock()
        pendingClients[ObjectIdentifier(client)] = client
        lock.unlock()

        client.start()
    }

    private func registerAndEvictExisting(_ client: ClientConnection) -> [ClientConnection] {
        lock.lock()
        let newID = ObjectIdentifier(client)
        pendingClients.removeValue(forKey: newID)
        let evicted = clients.filter { $0.key != newID }.map(\.value)
        clients = [newID: client]
        lock.unlock()
        return evicted
    }

    private func remove(_ client: ClientConnection) {
        lock.lock()
        let id = ObjectIdentifier(client)
        let wasActive = clients.removeValue(forKey: id) != nil
        pendingClients.removeValue(forKey: id)
        let noMoreActive = clients.isEmpty
        lock.unlock()

        if wasActive && noMoreActive {
            onClientDisconnected?()
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

private final class ClientConnection: @unchecked Sendable {
    private static let maxHTTPHeaderBytes = 16 * 1024

    private let connection: NWConnection
    private let upgradeHandler: WebSocketUpgradeHandler
    private let dispatcher: JSONRPCDispatcher
    private let onRejected: (NWEndpoint) -> Void
    private let onUpgraded: (ClientConnection) -> Void
    private let onClosed: (ClientConnection) -> Void

    private var upgraded = false
    private var headerBuffer = Data()
    private var frameBuffer = Data()
    private var requestCount = 0
    private var windowStart = Date()

    init(connection: NWConnection,
         upgradeHandler: WebSocketUpgradeHandler,
         dispatcher: JSONRPCDispatcher,
         onRejected: @escaping (NWEndpoint) -> Void,
         onUpgraded: @escaping (ClientConnection) -> Void,
         onClosed: @escaping (ClientConnection) -> Void) {
        self.connection = connection
        self.upgradeHandler = upgradeHandler
        self.dispatcher = dispatcher
        self.onRejected = onRejected
        self.onUpgraded = onUpgraded
        self.onClosed = onClosed
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                guard let self else { return }
                self.onClosed(self)
            }
        }
        connection.start(queue: .global(qos: .utility))
        receive()
    }

    func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func close() {
        connection.cancel()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if error != nil || isComplete {
                self.connection.cancel()
                return
            }

            if let data, !data.isEmpty {
                self.upgraded ? self.handleFrames(data) : self.handleUpgrade(data)
            }

            self.receive()
        }
    }

    private func handleUpgrade(_ data: Data) {
        headerBuffer.append(data)
        guard headerBuffer.count <= Self.maxHTTPHeaderBytes else {
            connection.cancel()
            return
        }
        let terminator = Data([13, 10, 13, 10])
        guard let headerEnd = headerBuffer.range(of: terminator) else { return }
        let requestData = headerBuffer[..<headerEnd.upperBound]
        let remainder = Data(headerBuffer[headerEnd.upperBound...])

        switch upgradeHandler.handle(requestData: Data(requestData)) {
        case .accept(let response):
            upgraded = true
            send(response)
            onUpgraded(self)
            if !remainder.isEmpty {
                handleFrames(remainder)
            }
        case .reject(let response):
            onRejected(connection.endpoint)
            send(response)
            connection.cancel()
        }
        headerBuffer.removeAll(keepingCapacity: false)
    }

    private func handleFrames(_ data: Data) {
        frameBuffer.append(data)

        while true {
            switch WebSocketFrameCodec.decode(from: frameBuffer) {
            case .frame(let frame, let consumed):
                frameBuffer.removeFirst(consumed)
                handle(frame)
            case .incomplete:
                return
            case .oversized:
                sendClose(code: 1009)
                connection.cancel()
                return
            case .protocolError:
                sendClose(code: 1002)
                connection.cancel()
                return
            }
        }
    }

    private func handle(_ frame: WebSocketFrame) {
        switch frame.opcode {
        case .text:
            if isRateLimited() {
                let response = buildRateLimitResponse(for: frame.payload)
                send(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .text, payload: response)))
                return
            }

            Task {
                let response = await dispatcher.dispatch(frame.payload)
                send(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .text, payload: response)))
            }
        case .ping:
            send(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .pong, payload: frame.payload)))
        case .close:
            sendClose(code: 1000)
            connection.cancel()
        default:
            break
        }
    }

    private func isRateLimited() -> Bool {
        let now = Date()
        if now.timeIntervalSince(windowStart) >= 1.0 {
            requestCount = 0
            windowStart = now
        }
        requestCount += 1
        return requestCount > 60
    }

    private func buildRateLimitResponse(for payload: Data) -> Data {
        struct ErrorResponse: Encodable {
            let jsonrpc = "2.0"
            let id: JSONValue
            let error: ErrorPayload
        }
        struct ErrorPayload: Encodable {
            let code = -32006
            let message = "Rate limit exceeded"
        }

        let recoveredId: JSONValue
        if let raw = try? JSONDecoder().decode(JSONValue.self, from: payload),
           let object = raw.object {
            switch object["id"] {
            case .string(let value): recoveredId = .string(value)
            case .int(let value): recoveredId = .int(value)
            default: recoveredId = .null
            }
        } else {
            recoveredId = .null
        }

        return (try? JSONEncoder().encode(ErrorResponse(id: recoveredId, error: ErrorPayload()))) ?? Data()
    }

    private func sendClose(code: UInt16) {
        let payload = Data([UInt8((code >> 8) & 0xff), UInt8(code & 0xff)])
        send(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .close, payload: payload)))
    }
}
