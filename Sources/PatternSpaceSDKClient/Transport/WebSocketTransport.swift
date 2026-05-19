import Foundation
import Network

final class WebSocketTransport: @unchecked Sendable {
    private var connection: NWConnection?
    var onMessage: ((Data) -> Void)?
    var onDisconnect: ((Error?) -> Void)?

    func connect(to endpoint: NWEndpoint, token: String?) {
        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        webSocketOptions.maximumMessageSize = 65_536
        if let token {
            webSocketOptions.setAdditionalHeaders([("Authorization", "Bearer \(token)")])
        }

        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receive()
            case .failed(let error):
                self?.onDisconnect?(error)
            case .cancelled:
                self?.onDisconnect?(nil)
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .utility))
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    func send(_ data: Data) {
        guard let connection else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func receive() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            if let error {
                self?.onDisconnect?(error)
                return
            }
            if let data, !data.isEmpty {
                self?.onMessage?(data)
            }
            self?.receive()
        }
    }
}
