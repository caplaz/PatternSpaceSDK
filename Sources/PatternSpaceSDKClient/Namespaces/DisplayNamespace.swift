import Foundation
import PatternSpaceSDKCore

/// Client namespace for `display.*` JSON-RPC methods.
public final class DisplayNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    /// Returns the display inventory and selected display metadata.
    public func list() async throws -> DisplayListResult {
        struct Params: Encodable {}
        let result = try await session.send(method: "display.list", params: Params(), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(DisplayListResult.self, from: data)
    }

    /// Sets the Peak White EDR value for the specified display.
    ///
    /// - Parameters:
    ///   - displayId: Identifier of the display to adjust.
    ///   - peakWhite: Desired peak-white EDR value within the display's `peakWhiteRange`.
    /// - Returns: Updated `DisplayEntry` reflecting the new peak-white value.
    public func setPeakWhite(displayId: String, peakWhite: Double) async throws -> DisplayEntry {
        let params = SetPeakWhiteParams(displayId: displayId, peakWhite: peakWhite)
        let result = try await session.send(method: "display.setPeakWhite", params: params, via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(DisplayEntry.self, from: data)
    }

    /// Lists available color-management modes for the specified display.
    public func listColorManagementModes(displayId: String) async throws -> ColorManagementModeList {
        struct Params: Encodable { let displayId: String }
        let result = try await session.send(method: "display.listColorManagementModes", params: Params(displayId: displayId), via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(ColorManagementModeList.self, from: data)
    }

    /// Sets the host-global color-management mode for the selected display.
    public func setColorManagementMode(displayId: String, mode: ColorManagementMode) async throws -> SetColorManagementModeResult {
        let params = SetColorManagementModeParams(displayId: displayId, mode: mode)
        let result = try await session.send(method: "display.setColorManagementMode", params: params, via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(SetColorManagementModeResult.self, from: data)
    }
}
