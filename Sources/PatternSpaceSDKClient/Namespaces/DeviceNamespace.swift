import Foundation
import PatternSpaceSDKCore

public final class DeviceNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    public func info() async throws -> DeviceInfo {
        struct Params: Encodable {}
        let result = try await session.send(method: "device.info", params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(DeviceInfo.self, from: data)
    }

    public func status() async throws -> DeviceStatus {
        struct Params: Encodable {}
        let result = try await session.send(method: "device.status", params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(DeviceStatus.self, from: data)
    }
}
