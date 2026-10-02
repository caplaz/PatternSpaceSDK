import Foundation
import PatternSpaceSDKCore

/// Client namespace for `output.*` JSON-RPC methods.
///
/// Check `CapabilitiesResult.outputBlank` before calling: hosts without blank
/// support reply with `methodNotFound`.
public final class OutputNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    /// Blanks the host output and returns the resulting status.
    ///
    /// Returns once the blank is confirmed, or with the current status when a
    /// newer output superseded it. Throws `PSDispatchError` with
    /// `outputNotConfirmed` when the blank failed or output state is unknown.
    public func blank() async throws -> OutputStatus {
        try await send(method: "output.blank")
    }

    /// Cancels a pending or active blank and returns the resulting status.
    ///
    /// Resume is a no-op when not blanked. Throws `PSDispatchError` with
    /// `outputNotConfirmed` when output state is unknown.
    public func resume() async throws -> OutputStatus {
        try await send(method: "output.resume")
    }

    private func send(method: String) async throws -> OutputStatus {
        struct Params: Encodable {}
        let result = try await session.send(method: method, params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(OutputStatus.self, from: data)
    }
}
