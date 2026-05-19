import Foundation
import Network
import PatternSpaceSDKCore

public struct PatternSpaceService: Sendable {
    public let name: String
    public let endpoint: NWEndpoint
    public let port: UInt16

    public init(name: String, endpoint: NWEndpoint, port: UInt16) {
        self.name = name
        self.endpoint = endpoint
        self.port = port
    }
}

public enum PatternSpaceClientError: Error, Sendable {
    case disconnected
}

public final class PatternSpaceClient: @unchecked Sendable {
    public let pattern: PatternNamespace
    public let device: DeviceNamespace

    private let service: PatternSpaceService
    private let token: String?
    private let transport = WebSocketTransport()
    private let session = JSONRPCSession()
    private let eventStream: AsyncStream<PatternSpaceEvent>
    private let eventContinuation: AsyncStream<PatternSpaceEvent>.Continuation
    private var intentionallyDisconnected = false
    private var reconnectDelay: TimeInterval = 1.0

    public init(service: PatternSpaceService, token: String? = nil) {
        self.service = service
        self.token = token
        (eventStream, eventContinuation) = AsyncStream.makeStream()
        pattern = PatternNamespace(session: session, transport: transport)
        device = DeviceNamespace(session: session, transport: transport)

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

    public var events: AsyncStream<PatternSpaceEvent> {
        eventStream
    }

    public func connect() {
        intentionallyDisconnected = false
        transport.connect(to: service.endpoint, token: token)
    }

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

        default:
            break
        }
    }
}
