import Foundation
import PatternSpaceSDKCore

/// Client namespace for `device.*` JSON-RPC methods.
public final class DeviceNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    /// Returns static and configuration information for the active display.
    public func info() async throws -> DeviceInfo {
        struct Params: Encodable {}
        let result = try await session.send(method: "device.info", params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(DeviceInfo.self, from: data)
    }

    /// Returns current runtime status for the PatternSpace app.
    public func status() async throws -> DeviceStatus {
        struct Params: Encodable {}
        let result = try await session.send(method: "device.status", params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(DeviceStatus.self, from: data)
    }
}
