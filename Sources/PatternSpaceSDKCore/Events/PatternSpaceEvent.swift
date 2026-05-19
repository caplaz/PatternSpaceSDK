// Sources/PatternSpaceSDKCore/Events/PatternSpaceEvent.swift
import Foundation

public enum PatternSpaceEvent: Sendable {
    case connectionReady(ConnectionReadyParams)
    case patternChanged(patternId: String?, source: String)
    case deviceStatusChanged(DeviceSnapshot)
    /// Emitted when the transport fails to connect or drops unexpectedly.
    /// The client will attempt automatic reconnection after this event.
    case connectionFailed(Error)
}
