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
