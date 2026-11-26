import Foundation
import Network
import PatternSpaceSDKCore

final class ClientConnection: @unchecked Sendable {
    private static let maxHTTPHeaderBytes = 16 * 1024

    enum Lifecycle {
        /// Accepted but not (yet) an authenticated, registered client.
        case pending
        /// Reported to `onClientConnected`; disconnect not yet reported.
        case registered
        /// `onClientDisconnected` has been delivered for this client.
        case disconnectNotified
    }

    /// Server-minted identity forwarded with every request from this client.
    let id = UUID()

    /// Guarded by the owning server's lock; transitions only on its lifecycle queue.
    var lifecycle: Lifecycle = .pending

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
    /// Set once a final message is queued; later input is ignored.
    private var closing = false

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

    /// Sends `data` as the final message and closes the connection once it has
    /// been written. Cancelling straight after `send` can discard the queued
    /// bytes, so a rejected client would see the socket close with no HTTP
    /// status (for example, no `401 Unauthorized` for a wrong pairing code).
    private func sendAndClose(_ data: Data) {
        closing = true
        connection.send(
            content: data,
            contentContext: .finalMessage,
            isComplete: true,
            completion: .contentProcessed { [connection] _ in connection.cancel() }
        )
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if error != nil || isComplete {
                self.connection.cancel()
                return
            }

            // A rejected or closing client gets no further processing.
            if self.closing { return }

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
            sendAndClose(response)
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
                return
            case .protocolError:
                sendClose(code: 1002)
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

            // Bind the identity before spawning async work so in-flight requests
            // keep the original client ID even after this client is replaced.
            let context = OutputRequestContext(clientID: id)
            let payload = frame.payload
            let dispatcher = dispatcher
            Task {
                let response = await dispatcher.dispatch(payload, context: context)
                send(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .text, payload: response)))
            }
        case .ping:
            send(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .pong, payload: frame.payload)))
        case .close:
            sendClose(code: 1000)
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

    /// Sends a close frame and closes the connection once it has been written.
    private func sendClose(code: UInt16) {
        let payload = Data([UInt8((code >> 8) & 0xff), UInt8(code & 0xff)])
        sendAndClose(WebSocketFrameCodec.encode(WebSocketFrame(opcode: .close, payload: payload)))
    }
}
