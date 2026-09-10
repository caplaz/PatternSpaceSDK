import Foundation
import Network

final class WebSocketTransport: @unchecked Sendable {
    private var task: URLSessionWebSocketTask?
    private var nativeConnection: NWConnection?
    private var hasReportedDisconnect = false
    var onMessage: ((Data) -> Void)?
    var onDisconnect: ((Error?) -> Void)?

    func connect(to endpoint: NWEndpoint, token: String?) {
        disconnectCurrentTask()
        hasReportedDisconnect = false

        if case .hostPort = endpoint {
            openWebSocket(to: endpoint, token: token)
        } else {
            openNativeWebSocket(to: endpoint, token: token)
        }
    }

    func disconnect() {
        disconnectCurrentTask()
    }

    func send(_ data: Data) {
        if let task, let message = String(data: data, encoding: .utf8) {
            Task { [weak self, weak task] in
                guard let self, let task else { return }
                do {
                    try await task.send(.string(message))
                } catch {
                    guard self.task === task else { return }
                    self.reportDisconnect(error)
                }
            }
            return
        }

        guard let nativeConnection else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        nativeConnection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func openWebSocket(to endpoint: NWEndpoint, token: String?) {
        guard let url = webSocketURL(for: endpoint) else {
            reportDisconnect(WebSocketTransportError.invalidEndpoint)
            return
        }

        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.webSocketTask(with: request)
        self.task = task
        task.resume()
        receive(from: task)
    }

    private func openNativeWebSocket(to endpoint: NWEndpoint, token: String?) {
        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        webSocketOptions.maximumMessageSize = 65_536
        if let token {
            webSocketOptions.setAdditionalHeaders([("Authorization", "Bearer \(token)")])
        }

        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let connection = NWConnection(to: endpoint, using: parameters)
        nativeConnection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection, self.nativeConnection === connection else { return }
            switch state {
            case .ready:
                self.receiveNative(from: connection)
            case .failed(let error):
                self.reportDisconnect(error)
            case .cancelled:
                self.reportDisconnect(nil)
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .utility))
    }

    private func receive(from task: URLSessionWebSocketTask) {
        Task { [weak self, weak task] in
            guard let self, let task else { return }
            do {
                let message = try await task.receive()
                guard self.task === task else { return }
                switch message {
                case .data(let data):
                    self.onMessage?(data)
                case .string(let text):
                    self.onMessage?(Data(text.utf8))
                @unknown default:
                    break
                }
                self.receive(from: task)
            } catch {
                guard self.task === task else { return }
                self.reportDisconnect(error)
            }
        }
    }

    private func receiveNative(from connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection, self.nativeConnection === connection else { return }
            if let error {
                self.reportDisconnect(error)
                return
            }
            if let data, !data.isEmpty {
                self.onMessage?(data)
            }
            self.receiveNative(from: connection)
        }
    }

    private func disconnectCurrentTask() {
        nativeConnection?.cancel()
        nativeConnection = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func reportDisconnect(_ error: Error?) {
        guard !hasReportedDisconnect else { return }
        hasReportedDisconnect = true
        disconnectCurrentTask()
        onDisconnect?(error)
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
