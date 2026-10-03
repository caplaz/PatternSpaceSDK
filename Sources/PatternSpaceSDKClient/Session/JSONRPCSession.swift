import Foundation
import PatternSpaceSDKCore

final class JSONRPCSession: @unchecked Sendable {
    /// A request awaiting its response. `generation` is the transport socket
    /// generation it was written to; nil until the transport accepts it.
    private struct Pending {
        let continuation: CheckedContinuation<JSONValue, Error>
        var generation: UInt64?
    }

    private var pending: [String: Pending] = [:]
    private let lock = NSLock()
    var onNotification: ((String, JSONValue?) -> Void)?

    func send<P: Encodable>(method: String, params: P, via transport: WebSocketTransport) async throws -> JSONValue {
        let id = UUID().uuidString
        let request = OutgoingRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pending[id] = Pending(continuation: continuation)
            lock.unlock()
            // Runs on the transport queue, before the write and before any
            // response or disconnect of that generation can be delivered.
            transport.send(data) { [weak self] generation in
                guard let self else { return }
                self.lock.lock()
                guard let generation else {
                    let rejected = self.pending.removeValue(forKey: id)
                    self.lock.unlock()
                    rejected?.continuation.resume(throwing: PatternSpaceClientError.disconnected)
                    return
                }
                self.pending[id]?.generation = generation
                self.lock.unlock()
            }
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
        let continuation = pending.removeValue(forKey: id)?.continuation
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

    /// Fails only the requests written to socket `generation`; requests of
    /// other generations, or not yet accepted by the transport, are untouched.
    func failPending(generation: UInt64, with error: Error) {
        lock.lock()
        let ids = pending.filter { $0.value.generation == generation }.map(\.key)
        let failed = ids.compactMap { pending.removeValue(forKey: $0)?.continuation }
        lock.unlock()
        failed.forEach { $0.resume(throwing: error) }
    }
}

private struct OutgoingRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: P
}
