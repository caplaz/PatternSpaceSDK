import Foundation

/// Platform on which PatternSpace is running.
public enum PlatformName: String, Codable, Sendable, Equatable {
    case macOS
    case iOS
}

/// Physical or logical connection type for a display.
public enum DisplayConnectionKind: String, Codable, Sendable, Equatable {
    case builtIn
    case wired
    case airPlay
    case unknown
}

/// The minimum and maximum EDR-relative peak-white values for a display.
public struct PeakWhiteRange: Codable, Sendable, Equatable {
    /// Protocol-specified absolute floor for peak-white control (0.25 EDR).
    public static let absoluteMinimum: Double = 0.25

    /// Minimum peak-white value accepted by the display.
    public let minimum: Double

    /// Maximum peak-white value accepted by the display.
    public let maximum: Double

    /// Creates a range, defaulting minimum to the protocol absolute floor.
    public init(minimum: Double = Self.absoluteMinimum, maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// A single display entry returned by `display.list`.
public struct DisplayEntry: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case selected
        case connection
        case resolution
        case refreshRate
        case colorSpaceName
        case cgColorSpaceName
        case maximumPotentialEDR
        case maximumCurrentEDR
        case peakWhite
        case effectivePeakWhite
        case peakWhiteRange
        case supportsPeakWhiteControl
        case displayProfileResolved
        case outputColorPresetId
        case supportedOutputColorPresetIds
        case outputColorPresetImplementationStatus
    }

    /// Stable display identifier (CGDirectDisplayID on macOS, UIScreen token on iOS).
    public let id: String

    /// User-visible display name.
    public let name: String

    /// Whether this display is currently selected for output.
    public let selected: Bool

    /// How the display is connected to the device.
    public let connection: DisplayConnectionKind

    /// Native pixel resolution of the display.
    public let resolution: Resolution

    /// Refresh rate in hertz, if available.
    public let refreshRate: Int?

    /// Human-readable color space name, if available.
    public let colorSpaceName: String?

    /// CoreGraphics color space name, if available.
    public let cgColorSpaceName: String?

    /// Maximum potential EDR headroom the display can achieve under ideal conditions.
    public let maximumPotentialEDR: Double

    /// Maximum EDR headroom the display can achieve given current ambient conditions.
    public let maximumCurrentEDR: Double

    /// Stored peak-white EDR value (user-configured or system default).
    public let peakWhite: Double

    /// Effective peak-white EDR value currently in use (may be clamped by OS).
    public let effectivePeakWhite: Double

    /// Accepted peak-white range for this display.
    public let peakWhiteRange: PeakWhiteRange

    /// Whether the app can programmatically adjust peak white for this display.
    public let supportsPeakWhiteControl: Bool

    /// Whether the display ICC/profile information could be resolved.
    public let displayProfileResolved: Bool?

    /// Host-global output color preset currently applied to patch output.
    public let outputColorPresetId: OutputColorPresetID?

    /// Output color preset IDs currently supported for this display.
    public let supportedOutputColorPresetIds: [OutputColorPresetID]

    /// Open-string implementation status for the selected output color preset.
    public let outputColorPresetImplementationStatus: String?

    /// Creates a display entry.
    public init(
        id: String,
        name: String,
        selected: Bool,
        connection: DisplayConnectionKind,
        resolution: Resolution,
        refreshRate: Int?,
        colorSpaceName: String?,
        cgColorSpaceName: String?,
        maximumPotentialEDR: Double,
        maximumCurrentEDR: Double,
        peakWhite: Double,
        effectivePeakWhite: Double,
        peakWhiteRange: PeakWhiteRange,
        supportsPeakWhiteControl: Bool
    ) {
        self.init(
            id: id,
            name: name,
            selected: selected,
            connection: connection,
            resolution: resolution,
            refreshRate: refreshRate,
            colorSpaceName: colorSpaceName,
            cgColorSpaceName: cgColorSpaceName,
            maximumPotentialEDR: maximumPotentialEDR,
            maximumCurrentEDR: maximumCurrentEDR,
            peakWhite: peakWhite,
            effectivePeakWhite: effectivePeakWhite,
            peakWhiteRange: peakWhiteRange,
            supportsPeakWhiteControl: supportsPeakWhiteControl,
            displayProfileResolved: nil,
            outputColorPresetId: nil,
            supportedOutputColorPresetIds: [],
            outputColorPresetImplementationStatus: nil
        )
    }

    /// Creates a display entry with output color preset metadata.
    public init(
        id: String,
        name: String,
        selected: Bool,
        connection: DisplayConnectionKind,
        resolution: Resolution,
        refreshRate: Int?,
        colorSpaceName: String?,
        cgColorSpaceName: String?,
        maximumPotentialEDR: Double,
        maximumCurrentEDR: Double,
        peakWhite: Double,
        effectivePeakWhite: Double,
        peakWhiteRange: PeakWhiteRange,
        supportsPeakWhiteControl: Bool,
        displayProfileResolved: Bool?,
        outputColorPresetId: OutputColorPresetID? = nil,
        supportedOutputColorPresetIds: [OutputColorPresetID] = [],
        outputColorPresetImplementationStatus: String? = nil
    ) {
        self.id = id
        self.name = name
        self.selected = selected
        self.connection = connection
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.colorSpaceName = colorSpaceName
        self.cgColorSpaceName = cgColorSpaceName
        self.maximumPotentialEDR = maximumPotentialEDR
        self.maximumCurrentEDR = maximumCurrentEDR
        self.peakWhite = peakWhite
        self.effectivePeakWhite = effectivePeakWhite
        self.peakWhiteRange = peakWhiteRange
        self.supportsPeakWhiteControl = supportsPeakWhiteControl
        self.displayProfileResolved = displayProfileResolved
        self.outputColorPresetId = outputColorPresetId
        self.supportedOutputColorPresetIds = supportedOutputColorPresetIds
        self.outputColorPresetImplementationStatus = outputColorPresetImplementationStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.selected = try container.decode(Bool.self, forKey: .selected)
        self.connection = try container.decode(DisplayConnectionKind.self, forKey: .connection)
        self.resolution = try container.decode(Resolution.self, forKey: .resolution)
        self.refreshRate = try container.decodeIfPresent(Int.self, forKey: .refreshRate)
        self.colorSpaceName = try container.decodeIfPresent(String.self, forKey: .colorSpaceName)
        self.cgColorSpaceName = try container.decodeIfPresent(String.self, forKey: .cgColorSpaceName)
        self.maximumPotentialEDR = try container.decode(Double.self, forKey: .maximumPotentialEDR)
        self.maximumCurrentEDR = try container.decode(Double.self, forKey: .maximumCurrentEDR)
        self.peakWhite = try container.decode(Double.self, forKey: .peakWhite)
        self.effectivePeakWhite = try container.decode(Double.self, forKey: .effectivePeakWhite)
        self.peakWhiteRange = try container.decode(PeakWhiteRange.self, forKey: .peakWhiteRange)
        self.supportsPeakWhiteControl = try container.decode(Bool.self, forKey: .supportsPeakWhiteControl)
        self.displayProfileResolved = try container.decodeIfPresent(Bool.self, forKey: .displayProfileResolved)
        self.outputColorPresetId = try container.decodeIfPresent(OutputColorPresetID.self, forKey: .outputColorPresetId)
        self.supportedOutputColorPresetIds = try container.decodeIfPresent([OutputColorPresetID].self, forKey: .supportedOutputColorPresetIds) ?? []
        self.outputColorPresetImplementationStatus = try container.decodeIfPresent(String.self, forKey: .outputColorPresetImplementationStatus)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(selected, forKey: .selected)
        try container.encode(connection, forKey: .connection)
        try container.encode(resolution, forKey: .resolution)
        try container.encodeIfPresent(refreshRate, forKey: .refreshRate)
        try container.encodeIfPresent(colorSpaceName, forKey: .colorSpaceName)
        try container.encodeIfPresent(cgColorSpaceName, forKey: .cgColorSpaceName)
        try container.encode(maximumPotentialEDR, forKey: .maximumPotentialEDR)
        try container.encode(maximumCurrentEDR, forKey: .maximumCurrentEDR)
        try container.encode(peakWhite, forKey: .peakWhite)
        try container.encode(effectivePeakWhite, forKey: .effectivePeakWhite)
        try container.encode(peakWhiteRange, forKey: .peakWhiteRange)
        try container.encode(supportsPeakWhiteControl, forKey: .supportsPeakWhiteControl)
        try container.encodeIfPresent(displayProfileResolved, forKey: .displayProfileResolved)
        try container.encodeIfPresent(outputColorPresetId, forKey: .outputColorPresetId)
        try container.encode(supportedOutputColorPresetIds, forKey: .supportedOutputColorPresetIds)
        try container.encodeIfPresent(outputColorPresetImplementationStatus, forKey: .outputColorPresetImplementationStatus)
    }
}

/// Result payload for the `display.list` method.
public struct DisplayListResult: Codable, Sendable, Equatable {
    /// Platform on which the server is running.
    public let platform: PlatformName

    /// Identifier of the currently selected display, if any.
    public let selectedDisplayId: String?

    /// All available displays on the device.
    public let displays: [DisplayEntry]

    /// Creates a display list result.
    public init(platform: PlatformName, selectedDisplayId: String?, displays: [DisplayEntry]) {
        self.platform = platform
        self.selectedDisplayId = selectedDisplayId
        self.displays = displays
    }
}

/// Parameters for the `display.setPeakWhite` method.
public struct SetPeakWhiteParams: Codable, Sendable, Equatable {
    /// Identifier of the display to adjust.
    public let displayId: String

    /// Desired peak-white EDR value.
    public let peakWhite: Double

    /// Creates set-peak-white parameters.
    public init(displayId: String, peakWhite: Double) {
        self.displayId = displayId
        self.peakWhite = peakWhite
    }
}
