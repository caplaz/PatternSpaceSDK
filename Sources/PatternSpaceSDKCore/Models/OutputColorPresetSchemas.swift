import Foundation

/// Open string identifier for an output color preset.
///
/// PatternSpace defines convenience constants for known presets, but hosts may
/// advertise additional IDs without requiring an SDK enum update.
public struct OutputColorPresetID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension OutputColorPresetID {
    static let deviceNative = Self(rawValue: "deviceNative")
    static let managedSRGB = Self(rawValue: "managedSRGB")
    static let managedDisplayP3 = Self(rawValue: "managedDisplayP3")
    static let managedRec2020 = Self(rawValue: "managedRec2020")
    static let hdrP3D65PQ = Self(rawValue: "hdrP3D65PQ")
    static let hdrBT2020PQ = Self(rawValue: "hdrBT2020PQ")
}

/// Server-advertised output color preset with open string semantics.
public struct OutputColorPreset: Codable, Equatable, Sendable {
    public let id: OutputColorPresetID
    public let label: String
    public let group: String
    public let dynamicRange: String
    public let gamut: String
    public let whitePoint: String?
    public let transferFunction: String
    public let measurementRange: String
    public let toneMapping: String
    public let implementationStatus: String
    public let supported: Bool
    public let requiresPro: Bool
    public let unsupportedReason: String?
    public let layerColorSpace: String?
    public let inputEncoding: String?
    public let edrHeadroomRequired: Double?
    public let edrHeadroomPotential: Double?
    public let edrHeadroomCurrent: Double?
    public let edrHeadroomReference: Double?
    public let referenceWhiteNits: Double?
    public let referenceWhiteNitsSource: String?
    public let peakLuminanceNits: Double?
    public let clipOnsetNits: Double?
    public let clipOnsetPQSignal: Double?

    public init(
        id: OutputColorPresetID,
        label: String,
        group: String,
        dynamicRange: String,
        gamut: String,
        whitePoint: String?,
        transferFunction: String,
        measurementRange: String,
        toneMapping: String,
        implementationStatus: String,
        supported: Bool,
        requiresPro: Bool,
        unsupportedReason: String? = nil,
        layerColorSpace: String? = nil,
        inputEncoding: String? = nil,
        edrHeadroomRequired: Double? = nil,
        edrHeadroomPotential: Double? = nil,
        edrHeadroomCurrent: Double? = nil,
        edrHeadroomReference: Double? = nil,
        referenceWhiteNits: Double? = nil,
        referenceWhiteNitsSource: String? = nil,
        peakLuminanceNits: Double? = nil,
        clipOnsetNits: Double? = nil,
        clipOnsetPQSignal: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.group = group
        self.dynamicRange = dynamicRange
        self.gamut = gamut
        self.whitePoint = whitePoint
        self.transferFunction = transferFunction
        self.measurementRange = measurementRange
        self.toneMapping = toneMapping
        self.implementationStatus = implementationStatus
        self.supported = supported
        self.requiresPro = requiresPro
        self.unsupportedReason = unsupportedReason
        self.layerColorSpace = layerColorSpace
        self.inputEncoding = inputEncoding
        self.edrHeadroomRequired = edrHeadroomRequired
        self.edrHeadroomPotential = edrHeadroomPotential
        self.edrHeadroomCurrent = edrHeadroomCurrent
        self.edrHeadroomReference = edrHeadroomReference
        self.referenceWhiteNits = referenceWhiteNits
        self.referenceWhiteNitsSource = referenceWhiteNitsSource
        self.peakLuminanceNits = peakLuminanceNits
        self.clipOnsetNits = clipOnsetNits
        self.clipOnsetPQSignal = clipOnsetPQSignal
    }
}

/// Result payload for `display.listOutputColorPresets`.
public struct OutputColorPresetList: Codable, Equatable, Sendable {
    public let displayId: String
    public let selectedPresetId: OutputColorPresetID?
    public let scope: ColorManagementScope
    public let presets: [OutputColorPreset]

    public init(
        displayId: String,
        selectedPresetId: OutputColorPresetID?,
        scope: ColorManagementScope,
        presets: [OutputColorPreset]
    ) {
        self.displayId = displayId
        self.selectedPresetId = selectedPresetId
        self.scope = scope
        self.presets = presets
    }
}

/// Parameters for `display.setOutputColorPreset`.
public struct SetOutputColorPresetParams: Codable, Equatable, Sendable {
    public let displayId: String
    public let presetId: OutputColorPresetID

    public init(displayId: String, presetId: OutputColorPresetID) {
        self.displayId = displayId
        self.presetId = presetId
    }
}

/// Result payload for `display.setOutputColorPreset`.
public struct SetOutputColorPresetResult: Codable, Equatable, Sendable {
    public let scope: ColorManagementScope
    public let selectedPresetId: OutputColorPresetID
    public let selectedDisplayId: String?
    public let display: DisplayEntry

    public init(
        scope: ColorManagementScope,
        selectedPresetId: OutputColorPresetID,
        selectedDisplayId: String?,
        display: DisplayEntry
    ) {
        self.scope = scope
        self.selectedPresetId = selectedPresetId
        self.selectedDisplayId = selectedDisplayId
        self.display = display
    }
}
