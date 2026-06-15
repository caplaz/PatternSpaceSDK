import Foundation

/// Color-management modes PatternSpace can apply to rendered patches.
public enum ColorManagementMode: String, Codable, CaseIterable, Sendable, Equatable {
    case deviceNative
    case managedSRGB
    case managedDisplayP3
    case managedRec2020
}

/// Implementation path used for a color-management mode.
public enum ColorManagementImplementationStatus: String, Codable, Sendable, Equatable {
    case native
    case profileFallback
    case unsupported
}

/// Encoding expected for incoming color values under a mode.
public enum ColorInputEncoding: String, Codable, Sendable, Equatable {
    case linearLight
    case displayCode
}

/// Scope affected by a color-management write.
public enum ColorManagementScope: String, Codable, Sendable, Equatable {
    case host
}

/// A supported or advertised color-management mode.
public struct ColorManagementModeEntry: Codable, Sendable, Equatable {
    public let id: ColorManagementMode
    public let label: String
    public let layerColorSpace: String
    public let inputEncoding: ColorInputEncoding
    public let implementationStatus: ColorManagementImplementationStatus
    public let supported: Bool
    public let requiresPro: Bool
    public let displayProfileResolved: Bool?

    public init(
        id: ColorManagementMode,
        label: String,
        layerColorSpace: String,
        inputEncoding: ColorInputEncoding,
        implementationStatus: ColorManagementImplementationStatus,
        supported: Bool,
        requiresPro: Bool,
        displayProfileResolved: Bool?
    ) {
        self.id = id
        self.label = label
        self.layerColorSpace = layerColorSpace
        self.inputEncoding = inputEncoding
        self.implementationStatus = implementationStatus
        self.supported = supported
        self.requiresPro = requiresPro
        self.displayProfileResolved = displayProfileResolved
    }
}

/// Result payload for `display.listColorManagementModes`.
public struct ColorManagementModeList: Codable, Sendable, Equatable {
    public let displayId: String
    public let selectedMode: ColorManagementMode?
    public let scope: ColorManagementScope
    public let modes: [ColorManagementModeEntry]

    public init(
        displayId: String,
        selectedMode: ColorManagementMode?,
        scope: ColorManagementScope,
        modes: [ColorManagementModeEntry]
    ) {
        self.displayId = displayId
        self.selectedMode = selectedMode
        self.scope = scope
        self.modes = modes
    }
}

/// Parameters for `display.setColorManagementMode`.
public struct SetColorManagementModeParams: Codable, Sendable, Equatable {
    public let displayId: String
    public let mode: ColorManagementMode

    public init(displayId: String, mode: ColorManagementMode) {
        self.displayId = displayId
        self.mode = mode
    }
}

/// Result payload for `display.setColorManagementMode`.
public struct SetColorManagementModeResult: Codable, Sendable, Equatable {
    public let scope: ColorManagementScope
    public let selectedDisplayId: String?
    public let display: DisplayEntry

    public init(scope: ColorManagementScope, selectedDisplayId: String?, display: DisplayEntry) {
        self.scope = scope
        self.selectedDisplayId = selectedDisplayId
        self.display = display
    }
}
