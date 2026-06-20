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
    static let extLinearSRGBHDR = Self(rawValue: "extLinearSRGBHDR")
    static let linearHDRP3D65 = Self(rawValue: "linearHDRP3D65")
    static let linearHDRBT2020 = Self(rawValue: "linearHDRBT2020")

    static let sdrReferenceSRGB = Self(rawValue: "sdrReferenceSRGB")
    static let sdrReferenceAdobeRGB1998 = Self(rawValue: "sdrReferenceAdobeRGB1998")
    static let sdrReferenceAppleRGB = Self(rawValue: "sdrReferenceAppleRGB")
    static let sdrReferenceProPhotoRGB = Self(rawValue: "sdrReferenceProPhotoRGB")
    static let sdrReferenceBT601SMPTEC = Self(rawValue: "sdrReferenceBT601SMPTEC")
    static let sdrReferenceBT601EBU = Self(rawValue: "sdrReferenceBT601EBU")
    static let sdrReferenceBT709Gamma22 = Self(rawValue: "sdrReferenceBT709Gamma22")
    static let sdrReferenceBT709Gamma24 = Self(rawValue: "sdrReferenceBT709Gamma24")
    static let sdrReferenceBT709BT1886 = Self(rawValue: "sdrReferenceBT709BT1886")
    static let sdrReferenceBT2020Gamma22 = Self(rawValue: "sdrReferenceBT2020Gamma22")
    static let sdrReferenceBT2020Gamma24 = Self(rawValue: "sdrReferenceBT2020Gamma24")
    static let sdrReferenceBT2020BT1886 = Self(rawValue: "sdrReferenceBT2020BT1886")
    static let sdrReferenceP3DCIGamma26 = Self(rawValue: "sdrReferenceP3DCIGamma26")
    static let sdrReferenceP3D65Gamma22 = Self(rawValue: "sdrReferenceP3D65Gamma22")
    static let sdrReferenceP3D65Gamma24 = Self(rawValue: "sdrReferenceP3D65Gamma24")
    static let sdrReferenceP3D65Gamma26 = Self(rawValue: "sdrReferenceP3D65Gamma26")
}

/// Common behavior for typed open-string preset metadata values.
public protocol OutputColorPresetOpenStringValue: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral
where RawValue == String,
    StringLiteralType == String,
    ExtendedGraphemeClusterLiteralType == String,
    UnicodeScalarLiteralType == String {
    var rawValue: String { get set }
    init(rawValue: String)
}

public extension OutputColorPresetOpenStringValue {
    init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct OutputColorPresetFamily: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetFamily {
    static let device = Self(rawValue: "device")
    static let sdrReference = Self(rawValue: "sdrReference")
    static let hdrReference = Self(rawValue: "hdrReference")
    static let linearHDR = Self(rawValue: "linearHDR")
}

public struct OutputColorPresetGamut: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetGamut {
    static let displayNative = Self(rawValue: "displayNative")
    static let srgb = Self(rawValue: "srgb")
    static let displayP3 = Self(rawValue: "displayP3")
    static let p3D65 = Self(rawValue: "p3D65")
    static let p3DCI = Self(rawValue: "p3DCI")
    static let bt601SMPTEC = Self(rawValue: "bt601SMPTEC")
    static let bt601EBU = Self(rawValue: "bt601EBU")
    static let bt709 = Self(rawValue: "bt709")
    static let bt2020 = Self(rawValue: "bt2020")
    static let adobeRGB1998 = Self(rawValue: "adobeRGB1998")
    static let appleRGB = Self(rawValue: "appleRGB")
    static let proPhotoRGB = Self(rawValue: "proPhotoRGB")
}

public struct OutputColorPresetWhitePoint: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetWhitePoint {
    static let displayNative = Self(rawValue: "displayNative")
    static let d50 = Self(rawValue: "d50")
    static let d60 = Self(rawValue: "d60")
    static let d65 = Self(rawValue: "d65")
    static let dci = Self(rawValue: "dci")
}

public struct OutputColorPresetTransfer: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetTransfer {
    static let displayNative = Self(rawValue: "displayNative")
    static let displayCode = Self(rawValue: "displayCode")
    static let linear = Self(rawValue: "linear")
    static let srgb = Self(rawValue: "srgb")
    static let gamma22 = Self(rawValue: "gamma2.2")
    static let gamma24 = Self(rawValue: "gamma2.4")
    static let gamma26 = Self(rawValue: "gamma2.6")
    static let bt1886 = Self(rawValue: "bt1886")
    static let pqSt2084 = Self(rawValue: "pqSt2084")
    static let proPhotoROMM = Self(rawValue: "proPhotoROMM")
}

public struct OutputColorPresetInputEncoding: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetInputEncoding {
    static let displayCode = Self(rawValue: "displayCode")
    static let linear = Self(rawValue: "linear")
    static let srgb = Self(rawValue: "srgb")
    static let gamma22 = Self(rawValue: "gamma2.2")
    static let gamma24 = Self(rawValue: "gamma2.4")
    static let gamma26 = Self(rawValue: "gamma2.6")
    static let bt1886 = Self(rawValue: "bt1886")
    static let pqSt2084 = Self(rawValue: "pqSt2084")
    static let proPhotoROMM = Self(rawValue: "proPhotoROMM")
}

public struct OutputColorPresetDynamicRange: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetDynamicRange {
    static let sdr = Self(rawValue: "sdr")
    static let hdr = Self(rawValue: "hdr")
}

public struct OutputColorPresetToneMapping: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetToneMapping {
    static let none = Self(rawValue: "none")
    static let rolloff = Self(rawValue: "rolloff")
}

public struct OutputColorPresetMeasurementRange: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetMeasurementRange {
    static let full = Self(rawValue: "full")
    static let legal = Self(rawValue: "legal")
}

public struct OutputColorPresetImplementationStatus: OutputColorPresetOpenStringValue {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension OutputColorPresetImplementationStatus {
    static let native = Self(rawValue: "native")
    static let profileFallback = Self(rawValue: "profileFallback")
    static let unsupported = Self(rawValue: "unsupported")
    static let insufficientHeadroom = Self(rawValue: "insufficientHeadroom")
}

/// Lightweight preset entry returned by `display.listOutputColorPresets`.
public struct OutputColorPresetSummary: Codable, Equatable, Sendable {
    public let id: OutputColorPresetID
    public let label: String
    public let group: String
    public let family: OutputColorPresetFamily
    public let supported: Bool
    public let requiresPro: Bool
    public let implementationStatus: OutputColorPresetImplementationStatus
    public let unsupportedReason: String?

    public init(
        id: OutputColorPresetID,
        label: String,
        group: String,
        family: OutputColorPresetFamily,
        supported: Bool,
        requiresPro: Bool,
        implementationStatus: OutputColorPresetImplementationStatus,
        unsupportedReason: String? = nil
    ) {
        self.id = id
        self.label = label
        self.group = group
        self.family = family
        self.supported = supported
        self.requiresPro = requiresPro
        self.implementationStatus = implementationStatus
        self.unsupportedReason = unsupportedReason
    }
}

/// Full color-science configuration for one output color preset.
public struct OutputColorPresetConfig: Codable, Equatable, Sendable {
    public let id: OutputColorPresetID
    public let label: String
    public let group: String
    public let family: OutputColorPresetFamily
    public let gamut: OutputColorPresetGamut
    public let whitePoint: OutputColorPresetWhitePoint
    public let transfer: OutputColorPresetTransfer
    public let dynamicRange: OutputColorPresetDynamicRange
    public let toneMapping: OutputColorPresetToneMapping
    public let inputEncoding: OutputColorPresetInputEncoding
    public let implementationStatus: OutputColorPresetImplementationStatus
    public let supported: Bool
    public let requiresPro: Bool
    public let unsupportedReason: String?
    public let layerColorSpace: String?
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
        family: OutputColorPresetFamily,
        gamut: OutputColorPresetGamut,
        whitePoint: OutputColorPresetWhitePoint,
        transfer: OutputColorPresetTransfer,
        dynamicRange: OutputColorPresetDynamicRange,
        toneMapping: OutputColorPresetToneMapping,
        inputEncoding: OutputColorPresetInputEncoding,
        implementationStatus: OutputColorPresetImplementationStatus,
        supported: Bool,
        requiresPro: Bool,
        unsupportedReason: String? = nil,
        layerColorSpace: String? = nil,
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
        self.family = family
        self.gamut = gamut
        self.whitePoint = whitePoint
        self.transfer = transfer
        self.dynamicRange = dynamicRange
        self.toneMapping = toneMapping
        self.inputEncoding = inputEncoding
        self.implementationStatus = implementationStatus
        self.supported = supported
        self.requiresPro = requiresPro
        self.unsupportedReason = unsupportedReason
        self.layerColorSpace = layerColorSpace
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
    private enum CodingKeys: String, CodingKey {
        case displayId
        case selectedPresetId
        case scope
        case catalogRevision
        case presets
    }

    public let displayId: String
    public let selectedPresetId: OutputColorPresetID?
    public let scope: ColorManagementScope

    /// Opaque host-catalog cache token. Stable across list/get while unchanged;
    /// changes whenever the preset set, summaries, or full configs change.
    public let catalogRevision: String

    public let presets: [OutputColorPresetSummary]

    public init(
        displayId: String,
        selectedPresetId: OutputColorPresetID?,
        scope: ColorManagementScope,
        catalogRevision: String = "",
        presets: [OutputColorPresetSummary]
    ) {
        self.displayId = displayId
        self.selectedPresetId = selectedPresetId
        self.scope = scope
        self.catalogRevision = catalogRevision
        self.presets = presets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayId = try container.decode(String.self, forKey: .displayId)
        selectedPresetId = try container.decodeIfPresent(OutputColorPresetID.self, forKey: .selectedPresetId)
        scope = try container.decode(ColorManagementScope.self, forKey: .scope)
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision) ?? ""
        presets = try container.decode([OutputColorPresetSummary].self, forKey: .presets)
    }
}

/// Parameters for `display.getOutputColorPreset`.
public struct GetOutputColorPresetParams: Codable, Equatable, Sendable {
    public let displayId: String
    public let presetId: OutputColorPresetID

    public init(displayId: String, presetId: OutputColorPresetID) {
        self.displayId = displayId
        self.presetId = presetId
    }
}

/// Result payload for `display.getOutputColorPreset`.
public struct GetOutputColorPresetResult: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case displayId
        case catalogRevision
        case preset
    }

    public let displayId: String

    /// Opaque host-catalog cache token. Stable across list/get while unchanged;
    /// changes whenever the preset set, summaries, or full configs change.
    public let catalogRevision: String

    public let preset: OutputColorPresetConfig

    public init(displayId: String, catalogRevision: String, preset: OutputColorPresetConfig) {
        self.displayId = displayId
        self.catalogRevision = catalogRevision
        self.preset = preset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayId = try container.decode(String.self, forKey: .displayId)
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision) ?? ""
        preset = try container.decode(OutputColorPresetConfig.self, forKey: .preset)
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

/// Parameters for `display.setMeasurementRange`.
public struct SetMeasurementRangeParams: Codable, Equatable, Sendable {
    public let displayId: String
    public let measurementRange: OutputColorPresetMeasurementRange

    public init(
        displayId: String,
        measurementRange: OutputColorPresetMeasurementRange
    ) {
        self.displayId = displayId
        self.measurementRange = measurementRange
    }
}

/// Result payload for `display.setMeasurementRange`.
public struct SetMeasurementRangeResult: Codable, Equatable, Sendable {
    public let scope: ColorManagementScope
    public let selectedMeasurementRange: OutputColorPresetMeasurementRange
    public let selectedDisplayId: String?
    public let display: DisplayEntry

    public init(
        scope: ColorManagementScope,
        selectedMeasurementRange: OutputColorPresetMeasurementRange,
        selectedDisplayId: String?,
        display: DisplayEntry
    ) {
        self.scope = scope
        self.selectedMeasurementRange = selectedMeasurementRange
        self.selectedDisplayId = selectedDisplayId
        self.display = display
    }
}
