// Sources/PatternSpaceSDKCore/Models/DeviceSchemas.swift
import Foundation

/// Pixel dimensions reported by a PatternSpace display target.
public struct Resolution: Codable, Sendable, Equatable {
    /// Horizontal pixel count.
    public let width: Int

    /// Vertical pixel count.
    public let height: Int

    /// Creates a display resolution value.
    public init(width: Int, height: Int) { self.width = width; self.height = height }
}

/// Configuration fields returned by `device.info`.
public struct DeviceInfo: Codable, Sendable, Equatable {
    /// User-visible device or display name.
    public let name: String

    /// Current output resolution.
    public let resolution: Resolution

    /// Color format description, such as RGB.
    public let colorFormat: String

    /// Current output bit depth.
    public let bitDepth: Int

    /// HDR mode description.
    public let hdrMode: String

    /// Refresh rate in hertz.
    public let refreshRate: Int

    /// Output range description, such as full or limited.
    public let outputRange: String

    /// Creates a device information snapshot.
    public init(name: String, resolution: Resolution, colorFormat: String,
                bitDepth: Int, hdrMode: String, refreshRate: Int, outputRange: String) {
        self.name = name; self.resolution = resolution; self.colorFormat = colorFormat
        self.bitDepth = bitDepth; self.hdrMode = hdrMode
        self.refreshRate = refreshRate; self.outputRange = outputRange
    }
}

/// Runtime fields returned by `device.status`.
public struct DeviceStatus: Codable, Sendable, Equatable {
    /// Identifier of the currently displayed pattern, if any.
    public let currentPatternId: String?

    /// Whether the JSON protocol source is active in the app.
    public let sourceActive: Bool

    /// User-visible source selected in the host app, if reported.
    public let selectedSource: String?

    /// Identifier of the currently selected display, if reported.
    public let selectedDisplayId: String?

    /// Host-global color-management mode currently applied to patch output.
    public let colorManagementMode: ColorManagementMode?

    /// Implementation path for the current color-management mode.
    public let colorManagementImplementationStatus: ColorManagementImplementationStatus?

    /// Whether the active display ICC/profile information could be resolved.
    public let displayProfileResolved: Bool?

    /// Scope affected by color-management writes.
    public let colorManagementScope: ColorManagementScope?

    /// Whether the JSON server requires authentication.
    public let authRequired: Bool?

    /// Connected JSON client count, if reported.
    public let connectedClientCount: Int?

    /// Host app marketing version, if reported.
    public let appVersion: String?

    /// Host app build number, if reported.
    public let buildNumber: String?

    /// PatternSpaceSDK version used by the host, if reported.
    public let sdkVersion: String?

    /// PatternSpace JSON protocol version used by the host, if reported.
    public let protocolVersion: String?

    /// Host-global output color preset currently selected, if reported.
    public let outputColorPresetId: OutputColorPresetID?

    /// Open-string implementation status for the selected output color preset.
    public let outputColorPresetImplementationStatus: String?

    /// Maximum potential EDR headroom for the selected output display.
    public let edrHeadroomPotential: Double?

    /// Current EDR headroom for the selected output display.
    public let edrHeadroomCurrent: Double?

    /// Reference EDR headroom reported by the selected output display.
    public let edrHeadroomReference: Double?

    /// Assumed absolute luminance of EDR 1.0, in nits.
    public let referenceWhiteNits: Double?

    /// Source of the reference-white assumption.
    public let referenceWhiteNitsSource: String?

    /// Absolute luminance where current EDR output clips, in nits.
    public let clipOnsetNits: Double?

    /// Normalized PQ/ST 2084 signal value where current EDR output clips.
    public let clipOnsetPQSignal: Double?

    /// Creates a runtime status value.
    public init(currentPatternId: String?, sourceActive: Bool) {
        self.init(
            currentPatternId: currentPatternId,
            sourceActive: sourceActive,
            selectedSource: nil,
            selectedDisplayId: nil,
            colorManagementMode: nil,
            colorManagementImplementationStatus: nil,
            displayProfileResolved: nil,
            colorManagementScope: nil,
            authRequired: nil,
            connectedClientCount: nil,
            appVersion: nil,
            buildNumber: nil,
            sdkVersion: nil,
            protocolVersion: nil,
            outputColorPresetId: nil,
            outputColorPresetImplementationStatus: nil,
            edrHeadroomPotential: nil,
            edrHeadroomCurrent: nil,
            edrHeadroomReference: nil,
            referenceWhiteNits: nil,
            referenceWhiteNitsSource: nil,
            clipOnsetNits: nil,
            clipOnsetPQSignal: nil
        )
    }

    /// Creates a runtime status value with optional integration metadata.
    public init(
        currentPatternId: String?,
        sourceActive: Bool,
        selectedSource: String?,
        selectedDisplayId: String?,
        colorManagementMode: ColorManagementMode?,
        colorManagementImplementationStatus: ColorManagementImplementationStatus?,
        displayProfileResolved: Bool?,
        colorManagementScope: ColorManagementScope?,
        authRequired: Bool?,
        connectedClientCount: Int?,
        appVersion: String?,
        buildNumber: String?,
        sdkVersion: String?,
        protocolVersion: String?,
        outputColorPresetId: OutputColorPresetID? = nil,
        outputColorPresetImplementationStatus: String? = nil,
        edrHeadroomPotential: Double? = nil,
        edrHeadroomCurrent: Double? = nil,
        edrHeadroomReference: Double? = nil,
        referenceWhiteNits: Double? = nil,
        referenceWhiteNitsSource: String? = nil,
        clipOnsetNits: Double? = nil,
        clipOnsetPQSignal: Double? = nil
    ) {
        self.currentPatternId = currentPatternId
        self.sourceActive = sourceActive
        self.selectedSource = selectedSource
        self.selectedDisplayId = selectedDisplayId
        self.colorManagementMode = colorManagementMode
        self.colorManagementImplementationStatus = colorManagementImplementationStatus
        self.displayProfileResolved = displayProfileResolved
        self.colorManagementScope = colorManagementScope
        self.authRequired = authRequired
        self.connectedClientCount = connectedClientCount
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.sdkVersion = sdkVersion
        self.protocolVersion = protocolVersion
        self.outputColorPresetId = outputColorPresetId
        self.outputColorPresetImplementationStatus = outputColorPresetImplementationStatus
        self.edrHeadroomPotential = edrHeadroomPotential
        self.edrHeadroomCurrent = edrHeadroomCurrent
        self.edrHeadroomReference = edrHeadroomReference
        self.referenceWhiteNits = referenceWhiteNits
        self.referenceWhiteNitsSource = referenceWhiteNitsSource
        self.clipOnsetNits = clipOnsetNits
        self.clipOnsetPQSignal = clipOnsetPQSignal
    }
}

/// Full device state sent with `device.statusChanged` notifications.
public struct DeviceSnapshot: Codable, Sendable, Equatable {
    /// User-visible device or display name.
    public let name: String

    /// Current output resolution.
    public let resolution: Resolution

    /// Color format description, such as RGB.
    public let colorFormat: String

    /// Current output bit depth.
    public let bitDepth: Int

    /// HDR mode description.
    public let hdrMode: String

    /// Refresh rate in hertz.
    public let refreshRate: Int

    /// Output range description, such as full or limited.
    public let outputRange: String

    /// Identifier of the currently displayed pattern, if any.
    public let currentPatternId: String?

    /// Whether the JSON protocol source is active in the app.
    public let sourceActive: Bool

    /// Creates a full device state snapshot.
    public init(name: String, resolution: Resolution, colorFormat: String,
                bitDepth: Int, hdrMode: String, refreshRate: Int, outputRange: String,
                currentPatternId: String?, sourceActive: Bool) {
        self.name = name; self.resolution = resolution; self.colorFormat = colorFormat
        self.bitDepth = bitDepth; self.hdrMode = hdrMode; self.refreshRate = refreshRate
        self.outputRange = outputRange; self.currentPatternId = currentPatternId
        self.sourceActive = sourceActive
    }
}

/// Parameters sent with the initial `connectionReady` notification.
public struct ConnectionReadyParams: Codable, Sendable {
    /// PatternSpace JSON protocol version.
    public let protocolVersion: String

    /// User-visible device or display name.
    public let name: String

    /// Current output resolution.
    public let resolution: Resolution

    /// Color format description, such as RGB.
    public let colorFormat: String

    /// Current output bit depth.
    public let bitDepth: Int

    /// HDR mode description.
    public let hdrMode: String

    /// Refresh rate in hertz.
    public let refreshRate: Int

    /// Output range description, such as full or limited.
    public let outputRange: String

    /// Identifier of the currently displayed pattern, if any.
    public let currentPatternId: String?

    /// Whether the JSON protocol source is active in the app.
    public let sourceActive: Bool

    /// Whether the WebSocket connection satisfied server authentication.
    public let authenticated: Bool

    /// Creates connection-ready notification parameters.
    public init(protocolVersion: String, name: String, resolution: Resolution,
                colorFormat: String, bitDepth: Int, hdrMode: String,
                refreshRate: Int, outputRange: String, currentPatternId: String?,
                sourceActive: Bool, authenticated: Bool) {
        self.protocolVersion = protocolVersion; self.name = name; self.resolution = resolution
        self.colorFormat = colorFormat; self.bitDepth = bitDepth; self.hdrMode = hdrMode
        self.refreshRate = refreshRate; self.outputRange = outputRange
        self.currentPatternId = currentPatternId; self.sourceActive = sourceActive
        self.authenticated = authenticated
    }
}
