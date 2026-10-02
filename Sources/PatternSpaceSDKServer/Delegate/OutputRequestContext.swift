// Sources/PatternSpaceSDKServer/Delegate/OutputRequestContext.swift
import Foundation

/// Origin of an output-write request, captured by the server at dispatch.
///
/// The server mints `clientID` when a WebSocket client is registered and
/// passes it with every request from that connection. It is never read from
/// JSON params. Hosts compare it with their current connection at acceptance
/// so a request from an evicted or closed client cannot mutate output.
public struct OutputRequestContext: Sendable, Equatable, Hashable {
    /// Server-assigned identity of the authenticated client connection.
    public let clientID: UUID

    /// Creates a request context for a client connection.
    public init(clientID: UUID) {
        self.clientID = clientID
    }
}
