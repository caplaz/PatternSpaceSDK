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
public enum PatternSpaceClientError: Error, Sendable {
    /// The WebSocket transport disconnected while a request was pending.
    case disconnected
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

    private let service: PatternSpaceService
    private let token: String?
    private let transport = WebSocketTransport()
    private let session = JSONRPCSession()
    private let eventStream: AsyncStream<PatternSpaceEvent>
    private let eventContinuation: AsyncStream<PatternSpaceEvent>.Continuation
    private var intentionallyDisconnected = false
    private var reconnectDelay: TimeInterval = 1.0

    /// Creates a client for a discovered PatternSpace service.
    ///
    /// - Parameters:
    ///   - service: Service returned by `PatternSpaceDiscovery`.
    ///   - token: Optional bearer token required by servers that enable auth.
    public init(service: PatternSpaceService, token: String? = nil) {
        self.service = service
        self.token = token
        (eventStream, eventContinuation) = AsyncStream.makeStream()
        pattern = PatternNamespace(session: session, transport: transport)
        device = DeviceNamespace(session: session, transport: transport)
        display = DisplayNamespace(session: session, transport: transport)

        session.onNotification = { [weak self] method, params in
            self?.handleNotification(method: method, params: params)
        }
        transport.onMessage = { [weak self] data in
            self?.session.receive(data: data)
        }
        transport.onDisconnect = { [weak self] error in
            guard let self else { return }
            self.session.failAllPending(with: error ?? PatternSpaceClientError.disconnected)
            guard !self.intentionallyDisconnected else { return }
            if let error {
                self.eventContinuation.yield(.connectionFailed(error))
            }
            self.scheduleReconnect()
        }
    }

    /// Stream of asynchronous server notifications and transport failures.
    public var events: AsyncStream<PatternSpaceEvent> {
        eventStream
    }

    /// Opens the WebSocket connection and starts automatic reconnection.
    public func connect() {
        intentionallyDisconnected = false
        transport.connect(to: service.endpoint, token: token)
    }

    /// Closes the connection and finishes the event stream.
    public func disconnect() {
        intentionallyDisconnected = true
        transport.disconnect()
        eventContinuation.finish()
    }

    private func scheduleReconnect() {
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !self.intentionallyDisconnected else { return }
            self.connect()
        }
    }

    private func handleNotification(method: String, params: JSONValue?) {
        switch method {
        case "connectionReady":
            reconnectDelay = 1.0
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
