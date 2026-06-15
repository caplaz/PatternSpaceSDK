import Foundation

/// App version metadata returned by `capabilities.list`.
public struct AppMetadata: Codable, Sendable, Equatable {
    public let name: String
    public let version: String
    public let build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }
}

/// Feature flags returned by `capabilities.list`.
public struct CapabilityFeatures: Codable, Sendable, Equatable {
    public let events: Bool
    public let displayInventory: Bool
    public let peakWhiteControl: Bool
    public let colorManagementModes: Bool
    public let measurementRange: Bool
    public let catalogPatterns: Bool
    public let customICCBuilder: Bool
    public let httpBridge: Bool

    public init(
        events: Bool,
        displayInventory: Bool,
        peakWhiteControl: Bool,
        colorManagementModes: Bool,
        measurementRange: Bool,
        catalogPatterns: Bool,
        customICCBuilder: Bool,
        httpBridge: Bool
    ) {
        self.events = events
        self.displayInventory = displayInventory
        self.peakWhiteControl = peakWhiteControl
        self.colorManagementModes = colorManagementModes
        self.measurementRange = measurementRange
        self.catalogPatterns = catalogPatterns
        self.customICCBuilder = customICCBuilder
        self.httpBridge = httpBridge
    }
}

/// Result payload for `capabilities.list`.
public struct CapabilitiesResult: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let app: AppMetadata
    public let sdkVersion: String
    public let platform: PlatformName
    public let authRequired: Bool
    public let namespaces: [String: [String]]
    public let features: CapabilityFeatures

    public init(
        protocolVersion: String,
        app: AppMetadata,
        sdkVersion: String,
        platform: PlatformName,
        authRequired: Bool,
        namespaces: [String: [String]],
        features: CapabilityFeatures
    ) {
        self.protocolVersion = protocolVersion
        self.app = app
        self.sdkVersion = sdkVersion
        self.platform = platform
        self.authRequired = authRequired
        self.namespaces = namespaces
        self.features = features
    }
}
