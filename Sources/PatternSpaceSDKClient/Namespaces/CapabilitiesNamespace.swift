import Foundation
import PatternSpaceSDKCore

/// Client namespace for `capabilities.*` JSON-RPC methods.
public final class CapabilitiesNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    /// Returns protocol, route, and feature metadata advertised by the server.
    public func list() async throws -> CapabilitiesResult {
        struct Params: Encodable {}
        let result = try await session.send(method: "capabilities.list", params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(CapabilitiesResult.self, from: data)
    }
}
