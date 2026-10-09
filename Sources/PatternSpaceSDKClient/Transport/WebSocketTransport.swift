import Foundation
import PatternSpaceSDKCore
import Network

/// WebSocket transport with a serialized delivery fence.
///
/// Every connect, disconnect, send, socket-state and receive delivery runs on
/// one private serial queue. Each socket generation gets a fresh
/// `connectionEpoch`; a receive captures the epoch before it starts and its
/// result is delivered only if that epoch is still current when the queue
/// processes it. Replacement and identity validation therefore share one
/// serialization boundary, so a late completion from a replaced socket can
/// never deliver a message or report a disconnect after the new socket's
/// traffic. Callbacks run on the queue; calls back into the transport from
/// them are enqueued, never dispatched synchronously.
///
/// On both paths a send error ends the socket (reported `.failed`), and a
/// server close frame or end of stream is reported as `.failed(nil)`, which
/// the client treats as a dropped connection and reconnects automatically.
final class WebSocketTransport: @unchecked Sendable {
    /// Raw result of one socket receive, before epoch validation.
    ///
    /// `@unchecked` only because `Error` payloads from URLSession/Network are
    /// not statically `Sendable`; the value is immutable once created.
    enum Outcome: @unchecked Sendable {
        case message(Data)
        case closed
        case failed(Error)
    }

    struct ReceiveCompletion: Sendable {
        let outcome: Outcome
    }

    /// Test seam invoked with every raw receive completion before it is
    /// handed to the transport queue; the hook must eventually call `deliver`.
    typealias ReceiveCompletionHook = @Sendable (ReceiveCompletion, _ deliver: @escaping @Sendable () -> Void) -> Void

    /// Why a socket generation ended.
    enum DisconnectReason {
        /// The socket failed or the server closed it.
        case failed(Error?)
        /// `connect` replaced it with a new socket.
        case replaced
        /// `disconnect` closed it.
        case closed
    }

    struct Disconnect {
        /// Generation passed to `send`'s acceptance callback for this socket.
        let generation: UInt64
        /// Caller-supplied tag from the `connect` that opened this socket.
        let tag: UInt64
        let reason: DisconnectReason
    }

    /// Invoked on the transport queue, in socket order, for the current socket only.
    var onMessage: ((Data) -> Void)?
    /// Invoked on the transport queue exactly once per socket generation,
    /// after that generation has been invalidated.
    var onDisconnect: ((Disconnect) -> Void)?

    private enum Socket {
        case urlSession(URLSessionWebSocketTask)
        case native(NWConnection)

        func cancel() {
            switch self {
            case .urlSession(let task): task.cancel(with: .normalClosure, reason: nil)
            case .native(let connection): connection.cancel()
            }
        }
    }

    private let queue = DispatchQueue(label: "com.caplaz.PatternSpaceSDK.WebSocketTransport")
    private let receiveCompletionHook: ReceiveCompletionHook?
    // Queue-confined state.
    private var connectionEpoch: UInt64 = 0
    private var socket: Socket?
    private var socketTag: UInt64 = 0

    init(receiveCompletionHook: ReceiveCompletionHook? = nil) {
        self.receiveCompletionHook = receiveCompletionHook
    }

    /// Replaces any current socket (reporting it `.replaced` first) and opens a new one.
    func connect(to endpoint: NWEndpoint, token: String?, tag: UInt64 = 0) {
        queue.async { [self] in
            endCurrentSocket(.replaced)
            connectionEpoch &+= 1
            socketTag = tag
            if case .hostPort = endpoint {
                openWebSocket(to: endpoint, token: token, epoch: connectionEpoch)
            } else {
                openNativeWebSocket(to: endpoint, token: token, epoch: connectionEpoch)
            }
        }
    }

    func disconnect() {
        queue.async { [self] in endCurrentSocket(.closed) }
    }

    /// Sends `data` on the current socket. `accepted` runs on the transport
    /// queue before the write with the socket's generation, or nil when no
    /// socket is open (the message is then dropped).
    func send(_ data: Data, accepted: @escaping (UInt64?) -> Void) {
        queue.async { [self] in
            guard let socket else {
                accepted(nil)
                return
            }
            let epoch = connectionEpoch
            accepted(epoch)
            switch socket {
            case .urlSession(let task):
                let message = String(decoding: data, as: UTF8.self)
                task.send(.string(message)) { [weak self] error in
                    guard let self, let error else { return }
                    self.queue.async { self.fail(epoch: epoch, error) }
                }
            case .native(let connection):
                let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
                let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
                connection.send(
                    content: data, contentContext: context, isComplete: true,
                    completion: .contentProcessed { [weak self] error in
                        guard let self, let error else { return }
                        self.queue.async { self.fail(epoch: epoch, error) }
                    }
                )
            }
        }
    }

    /// Blocks until every operation already enqueued has run. Test-only.
    func flushForTesting() {
        queue.sync {}
    }

    // MARK: - Queue-confined

    private func openWebSocket(to endpoint: NWEndpoint, token: String?, epoch: UInt64) {
        guard let url = webSocketURL(for: endpoint) else {
            // Invalidate the generation before reporting it, as `endCurrentSocket` does.
            connectionEpoch &+= 1
            onDisconnect?(Disconnect(generation: epoch, tag: socketTag,
                                     reason: .failed(WebSocketTransportError.invalidEndpoint)))
            return
        }

        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.webSocketTask(with: request)
        task.maximumMessageSize = SignalSnapshotResponse.maximumPayloadBytes
        socket = .urlSession(task)
        task.resume()
        receive(from: task, epoch: epoch)
    }

    private func openNativeWebSocket(to endpoint: NWEndpoint, token: String?, epoch: UInt64) {
        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        webSocketOptions.maximumMessageSize = SignalSnapshotResponse.maximumPayloadBytes
        if let token {
            webSocketOptions.setAdditionalHeaders([("Authorization", "Bearer \(token)")])
        }

        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let connection = NWConnection(to: endpoint, using: parameters)
        socket = .native(connection)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.queue.async {
                    guard epoch == self.connectionEpoch, let connection else { return }
                    self.receiveNative(from: connection, epoch: epoch)
                }
            case .failed(let error):
                self.complete(ReceiveCompletion(outcome: .failed(error)), epoch: epoch)
            case .cancelled:
                self.complete(ReceiveCompletion(outcome: .closed), epoch: epoch)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(from task: URLSessionWebSocketTask, epoch: UInt64) {
        task.receive { [weak self] result in
            let outcome: Outcome
            switch result {
            case .success(.data(let data)): outcome = .message(data)
            case .success(.string(let text)): outcome = .message(Data(text.utf8))
            case .success: outcome = .message(Data())
            case .failure(let error): outcome = .failed(error)
            }
            self?.complete(ReceiveCompletion(outcome: outcome), epoch: epoch)
        }
    }

    private func receiveNative(from connection: NWConnection, epoch: UInt64) {
        connection.receiveMessage { [weak self] data, context, _, error in
            let outcome: Outcome
            if let error {
                outcome = .failed(error)
            } else if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                        as? NWProtocolWebSocket.Metadata, metadata.opcode == .close {
                outcome = .closed
            } else if let data {
                outcome = .message(data)
            } else {
                outcome = .closed
            }
            self?.complete(ReceiveCompletion(outcome: outcome), epoch: epoch)
        }
    }

    /// Routes a raw completion (any thread) through the test hook onto the queue.
    private func complete(_ completion: ReceiveCompletion, epoch: UInt64) {
        let deliver: @Sendable () -> Void = { [weak self] in
            guard let self else { return }
            self.queue.async { self.deliver(completion, epoch: epoch) }
        }
        if let receiveCompletionHook {
            receiveCompletionHook(completion, deliver)
        } else {
            deliver()
        }
    }

    private func deliver(_ completion: ReceiveCompletion, epoch: UInt64) {
        // Identity validation and delivery happen in the same queue block.
        guard epoch == connectionEpoch, let socket else { return }
        switch completion.outcome {
        case .message(let data):
            if !data.isEmpty {
                onMessage?(data)
            }
            switch socket {
            case .urlSession(let task): receive(from: task, epoch: epoch)
            case .native(let connection): receiveNative(from: connection, epoch: epoch)
            }
        case .closed:
            endCurrentSocket(.failed(nil))
        case .failed(let error):
            endCurrentSocket(.failed(error))
        }
    }

    private func fail(epoch: UInt64, _ error: Error) {
        guard epoch == connectionEpoch, socket != nil else { return }
        endCurrentSocket(.failed(error))
    }

    /// Invalidates the current generation, then cancels the socket and reports it.
    private func endCurrentSocket(_ reason: DisconnectReason) {
        guard let socket else { return }
        let generation = connectionEpoch
        connectionEpoch &+= 1
        self.socket = nil
        socket.cancel()
        onDisconnect?(Disconnect(generation: generation, tag: socketTag, reason: reason))
    }

    private func webSocketURL(for endpoint: NWEndpoint) -> URL? {
        guard case let .hostPort(host, port) = endpoint else { return nil }
        var components = URLComponents()
        components.scheme = "ws"
        let hostString = String(describing: host)
        components.host = hostString.contains(":")
            ? "[\(hostString)]"
            : String(hostString.split(separator: "%", maxSplits: 1).first ?? "")
        components.port = Int(port.rawValue)
        components.path = "/patternspace"
        return components.url
    }
}

private enum WebSocketTransportError: LocalizedError {
    case invalidEndpoint

    var errorDescription: String? {
        "The PatternSpace service endpoint is invalid"
    }
}
