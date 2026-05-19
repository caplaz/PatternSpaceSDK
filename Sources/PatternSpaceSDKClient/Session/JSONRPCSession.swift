import Foundation
import PatternSpaceSDKCore

final class JSONRPCSession: @unchecked Sendable {
    private var pending: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private let lock = NSLock()
    var onNotification: ((String, JSONValue?) -> Void)?

    func send<P: Encodable>(method: String, params: P, via transport: WebSocketTransport) async throws -> JSONValue {
        let id = UUID().uuidString
        let request = OutgoingRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pending[id] = continuation
            lock.unlock()
            transport.send(data)
        }
    }

    func receive(data: Data) {
        guard let envelope = try? JSONDecoder().decode(JSONValue.self, from: data),
              let object = envelope.object else { return }

        if let method = object["method"]?.string, object["id"] == nil {
            onNotification?(method, object["params"])
            return
        }

        guard let id = object["id"]?.string else { return }
        lock.lock()
        let continuation = pending.removeValue(forKey: id)
        lock.unlock()

        if let result = object["result"] {
            continuation?.resume(returning: result)
        } else if let errorObject = object["error"]?.object,
                  let code = errorObject["code"]?.int,
                  let message = errorObject["message"]?.string {
            let error = PSDispatchError(PSErrorCode(rawValue: code) ?? .internalError, message: message)
            continuation?.resume(throwing: error)
        }
    }

    func failAllPending(with error: Error) {
        lock.lock()
        let snapshot = pending
        pending.removeAll()
        lock.unlock()
        snapshot.values.forEach { $0.resume(throwing: error) }
    }
}

private struct OutgoingRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: P
}
