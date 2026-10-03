import Foundation
import Network
import PatternSpaceSDKCore

/// A PatternSpace service discovered on the local network.
public struct PatternSpaceService: Sendable {
    /// Bonjour service name advertised by the PatternSpace app.
    public let name: String

    /// Network endpoint used by the client transport.
    public let endpoint: NWEndpoint

    /// TCP port used by the PatternSpace JSON protocol.
    public let port: UInt16

    /// Creates a discovered service descriptor.
    public init(name: String, endpoint: NWEndpoint, port: UInt16) {
        self.name = name
        self.endpoint = endpoint
        self.port = port
    }
}

/// Errors raised by the high-level PatternSpace client.
public enum PatternSpaceClientError: Error, LocalizedError, Sendable {
    /// The WebSocket transport disconnected while a request was pending.
    case disconnected

    public var errorDescription: String? {
        switch self {
        case .disconnected: return "The server closed the connection"
        }
    }
}

/// High-level client for the PatternSpace JSON protocol.
///
/// Use `PatternSpaceDiscovery` to locate a running app, create a client with
/// the discovered service, then call methods on the `pattern` and `device`
/// namespaces.
public final class PatternSpaceClient: @unchecked Sendable {
    /// Pattern-related JSON-RPC methods.
    public let pattern: PatternNamespace

    /// Device information and status methods.
    public let device: DeviceNamespace

    /// Display inventory and peak-white control methods.
    public let display: DisplayNamespace

    /// Protocol feature and route discovery methods.
    public let capabilities: CapabilitiesNamespace

    /// Output blank and resume methods.
    public let output: OutputNamespace

    private let service: PatternSpaceService
    private let token: String?
    private let transport: WebSocketTransport
    private let session = JSONRPCSession()
    private let eventStream: AsyncStream<PatternSpaceEvent>
    private let eventContinuation: AsyncStream<PatternSpaceEvent>.Continuation
    private let initialReconnectDelay: TimeInterval
    // Guarded by `lifecycleLock`. `lifecycleGeneration` advances on every
    // connect, automatic reconnect and disconnect; it tags each transport
    // socket and fences scheduled reconnects against later lifecycle calls.
    private let lifecycleLock = NSLock()
    private var intentionallyDisconnected = false
    private var lifecycleGeneration: UInt64 = 0
    private var reconnectDelay: TimeInterval

    /// Creates a client for a discovered PatternSpace service.
    ///
    /// - Parameters:
    ///   - service: Service returned by `PatternSpaceDiscovery`.
    ///   - token: Optional bearer token required by servers that enable auth.
    public convenience init(service: PatternSpaceService, token: String? = nil) {
        self.init(service: service, token: token, transport: WebSocketTransport(), reconnectDelay: 1.0)
    }

    init(service: PatternSpaceService, token: String?, transport: WebSocketTransport, reconnectDelay: TimeInterval) {
        self.transport = transport
        self.initialReconnectDelay = reconnectDelay
        self.reconnectDelay = reconnectDelay
        self.service = service
        self.token = token
        (eventStream, eventContinuation) = AsyncStream.makeStream()
        pattern = PatternNamespace(session: session, transport: transport)
        device = DeviceNamespace(session: session, transport: transport)
        display = DisplayNamespace(session: session, transport: transport)
        capabilities = CapabilitiesNamespace(session: session, transport: transport)
        output = OutputNamespace(session: session, transport: transport)

        // Both callbacks run on the transport's serial queue, so responses,
        // notifications and disconnects are handled in socket order.
        session.onNotification = { [weak self] method, params in
            self?.handleNotification(method: method, params: params)
        }
        // `session` is captured strongly (it holds no reference back to the
        // transport) so responses and disconnect failures still reach pending
        // calls made through a retained namespace after the client is released.
        let session = session
        transport.onMessage = { data in
            session.receive(data: data)
        }
        transport.onDisconnect = { [weak self] disconnect in
            // The transport has already invalidated this generation, so
            // nothing from it can be delivered after its pending calls fail.
            if case .failed(let error?) = disconnect.reason {
                session.failPending(generation: disconnect.generation, with: error)
            } else {
                session.failPending(generation: disconnect.generation, with: PatternSpaceClientError.disconnected)
            }
            self?.handleDisconnect(disconnect)
        }
    }

    /// Stream of asynchronous server notifications and transport failures.
    public var events: AsyncStream<PatternSpaceEvent> {
        eventStream
    }

    /// Opens the WebSocket connection and starts automatic reconnection.
    ///
    /// Calling this while connected replaces the current connection; requests
    /// pending on the replaced connection fail with
    /// `PatternSpaceClientError.disconnected`.
    public func connect() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        intentionallyDisconnected = false
        startConnectionLocked()
    }

    /// Closes the connection and finishes the event stream.
    ///
    /// Requests still pending fail with `PatternSpaceClientError.disconnected`
    /// asynchronously, once the transport has closed the socket — including
    /// when the client is released immediately afterwards.
    public func disconnect() {
        lifecycleLock.lock()
        intentionallyDisconnected = true
        lifecycleGeneration &+= 1
        transport.disconnect()
        lifecycleLock.unlock()
        eventContinuation.finish()
    }

    /// Must hold `lifecycleLock`, so transport operations are enqueued in
    /// lifecycle order.
    private func startConnectionLocked() {
        lifecycleGeneration &+= 1
        transport.connect(to: service.endpoint, token: token, tag: lifecycleGeneration)
    }

    /// Reports a failed socket and schedules reconnection; pending calls of
    /// that generation were already failed by the `onDisconnect` closure.
    private func handleDisconnect(_ disconnect: WebSocketTransport.Disconnect) {
        guard case .failed(let error) = disconnect.reason else { return }
        let reason = error ?? PatternSpaceClientError.disconnected

        lifecycleLock.lock()
        let isCurrent = !intentionallyDisconnected && disconnect.tag == lifecycleGeneration
        let delay = reconnectDelay
        if isCurrent { reconnectDelay = min(reconnectDelay * 2, 30) }
        lifecycleLock.unlock()
        guard isCurrent else { return }

        eventContinuation.yield(.connectionFailed(reason))
        scheduleReconnect(after: delay, generation: disconnect.tag)
    }

    private func scheduleReconnect(after delay: TimeInterval, generation: UInt64) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.reconnect(ifStillAt: generation)
        }
    }

    /// Reconnects only if no connect, reconnect or disconnect happened since
    /// the failure that scheduled it.
    private func reconnect(ifStillAt generation: UInt64) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard !intentionallyDisconnected, lifecycleGeneration == generation else { return }
        startConnectionLocked()
    }

    private func handleNotification(method: String, params: JSONValue?) {
        switch method {
        case "connectionReady":
            lifecycleLock.lock()
            reconnectDelay = initialReconnectDelay
            lifecycleLock.unlock()
            guard let params,
                  let data = try? JSONEncoder().encode(params),
                  let ready = try? JSONDecoder().decode(ConnectionReadyParams.self, from: data) else { return }
            eventContinuation.yield(.connectionReady(ready))

        case "pattern.changed":
            let patternId = params?.object?["patternId"]?.string
            let source = params?.object?["source"]?.string ?? "unknown"
            eventContinuation.yield(.patternChanged(patternId: patternId, source: source))

        case "device.statusChanged":
            guard let params,
                  let data = try? JSONEncoder().encode(params),
                  let snapshot = try? JSONDecoder().decode(DeviceSnapshot.self, from: data) else { return }
            eventContinuation.yield(.deviceStatusChanged(snapshot))

        case "display.changed":
            guard let params,
                  let data = try? JSONEncoder().encode(params),
                  let result = try? JSONDecoder().decode(DisplayListResult.self, from: data) else { return }
            eventContinuation.yield(.displayChanged(result))

        default:
            break
        }
    }
}
