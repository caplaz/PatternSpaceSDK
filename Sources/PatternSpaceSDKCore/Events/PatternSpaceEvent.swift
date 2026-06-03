// Sources/PatternSpaceSDKCore/Events/PatternSpaceEvent.swift
import Foundation

/// Client-side event stream emitted by `PatternSpaceClient`.
public enum PatternSpaceEvent: Sendable {
    /// Emitted after the WebSocket connection is accepted and the server sends
    /// its initial device snapshot.
    case connectionReady(ConnectionReadyParams)

    /// Emitted when the active pattern changes.
    case patternChanged(patternId: String?, source: String)

    /// Emitted when runtime device status changes.
    case deviceStatusChanged(DeviceSnapshot)

    /// Emitted when the transport fails to connect or drops unexpectedly.
    /// The client will attempt automatic reconnection after this event.
    case connectionFailed(Error)

    /// Emitted when the display inventory, selection, or Peak White values change.
    case displayChanged(DisplayListResult)
}
