// Sources/PatternSpaceSDKCore/Models/DeviceSchemas.swift
import Foundation

public struct Resolution: Codable, Sendable, Equatable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) { self.width = width; self.height = height }
}

/// Configuration fields — returned by device.info
public struct DeviceInfo: Codable, Sendable, Equatable {
    public let name: String
    public let resolution: Resolution
    public let colorFormat: String
    public let bitDepth: Int
    public let hdrMode: String
    public let refreshRate: Int
    public let outputRange: String

    public init(name: String, resolution: Resolution, colorFormat: String,
                bitDepth: Int, hdrMode: String, refreshRate: Int, outputRange: String) {
        self.name = name; self.resolution = resolution; self.colorFormat = colorFormat
        self.bitDepth = bitDepth; self.hdrMode = hdrMode
        self.refreshRate = refreshRate; self.outputRange = outputRange
    }
}

/// Runtime fields — returned by device.status
public struct DeviceStatus: Codable, Sendable, Equatable {
    public let currentPatternId: String?
    public let connectedClients: Int
    public let sourceActive: Bool

    public init(currentPatternId: String?, connectedClients: Int, sourceActive: Bool) {
        self.currentPatternId = currentPatternId
        self.connectedClients = connectedClients
        self.sourceActive = sourceActive
    }
}

/// Full state — params of device.statusChanged
public struct DeviceSnapshot: Codable, Sendable, Equatable {
    public let name: String
    public let resolution: Resolution
    public let colorFormat: String
    public let bitDepth: Int
    public let hdrMode: String
    public let refreshRate: Int
    public let outputRange: String
    public let currentPatternId: String?
    public let connectedClients: Int
    public let sourceActive: Bool

    public init(name: String, resolution: Resolution, colorFormat: String,
                bitDepth: Int, hdrMode: String, refreshRate: Int, outputRange: String,
                currentPatternId: String?, connectedClients: Int, sourceActive: Bool) {
        self.name = name; self.resolution = resolution; self.colorFormat = colorFormat
        self.bitDepth = bitDepth; self.hdrMode = hdrMode; self.refreshRate = refreshRate
        self.outputRange = outputRange; self.currentPatternId = currentPatternId
        self.connectedClients = connectedClients; self.sourceActive = sourceActive
    }
}

/// Params of the connectionReady event — DeviceSnapshot + protocolVersion + authenticated
public struct ConnectionReadyParams: Codable, Sendable {
    public let protocolVersion: String
    public let name: String
    public let resolution: Resolution
    public let colorFormat: String
    public let bitDepth: Int
    public let hdrMode: String
    public let refreshRate: Int
    public let outputRange: String
    public let currentPatternId: String?
    public let connectedClients: Int
    public let sourceActive: Bool
    public let authenticated: Bool

    public init(protocolVersion: String, name: String, resolution: Resolution,
                colorFormat: String, bitDepth: Int, hdrMode: String,
                refreshRate: Int, outputRange: String, currentPatternId: String?,
                connectedClients: Int, sourceActive: Bool, authenticated: Bool) {
        self.protocolVersion = protocolVersion; self.name = name; self.resolution = resolution
        self.colorFormat = colorFormat; self.bitDepth = bitDepth; self.hdrMode = hdrMode
        self.refreshRate = refreshRate; self.outputRange = outputRange
        self.currentPatternId = currentPatternId; self.connectedClients = connectedClients
        self.sourceActive = sourceActive; self.authenticated = authenticated
    }
}
