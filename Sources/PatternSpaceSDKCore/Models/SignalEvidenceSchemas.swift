import Foundation

/// Open machine-readable vocabulary. Unknown tokens are preserved, never interpreted as success.
/// Consumers must use an unknown/unavailable presentation for tokens they do not recognize.
public struct SignalToken: RawRepresentable, Codable, Sendable, Equatable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    public static let current = Self(rawValue: "current")
    public static let historical = Self(rawValue: "historical")
    public static let collecting = Self(rawValue: "collecting")
    public static let available = Self(rawValue: "available")
    public static let unknown = Self(rawValue: "unknown")
    public static let notApplicable = Self(rawValue: "notApplicable")
    public static let received = Self(rawValue: "received")
    public static let calculated = Self(rawValue: "calculated")
    public static let appReported = Self(rawValue: "appReported")
    public static let packed = Self(rawValue: "packed")
    public static let confirmed = Self(rawValue: "confirmed")
    public static let pending = Self(rawValue: "pending")
    public static let failed = Self(rawValue: "failed")
    public static let superseded = Self(rawValue: "superseded")
    public static let readerBusy = Self(rawValue: "readerBusy")
    public static let timedOut = Self(rawValue: "timedOut")
    public static let nonFinite = Self(rawValue: "nonFinite")
    public static let payloadLimit = Self(rawValue: "payloadLimit")
    public static let rectangleLimit = Self(rawValue: "rectangleLimit")
    public static let background = Self(rawValue: "background")
    public static let rectangle = Self(rawValue: "rectangle")
    public static let receivedInteger = Self(rawValue: "receivedInteger")
    public static let receivedNormalized = Self(rawValue: "receivedNormalized")
    public static let receivedCodeValue = Self(rawValue: "receivedCodeValue")
}

/// Unix seconds for the independently captured interval. No atomic OS-settings claim is implied.
public struct SignalCaptureInterval: Codable, Sendable, Equatable {
    public let startedAt: Double
    public let completedAt: Double
    public init(startedAt: Double, completedAt: Double) {
        self.startedAt = startedAt.isFinite ? startedAt : 0
        self.completedAt = completedAt.isFinite ? completedAt : self.startedAt
    }
}

/// A typed scalar observation; `name` and tokens are stable machine keys, not localized text.
public struct SignalFieldEvidence: Codable, Sendable, Equatable {
    public let name: String
    public let provenance: SignalToken
    public let number: Double?
    public let integer: Int64?
    public let token: SignalToken?
    public let flag: Bool?
    public let text: String?
    public let units: SignalToken?
    public let reason: SignalToken?
    public let capture: SignalCaptureInterval?
    public init(name: String, provenance: SignalToken, number: Double? = nil,
                integer: Int64? = nil, token: SignalToken? = nil, flag: Bool? = nil,
                text: String? = nil, units: SignalToken? = nil, reason: SignalToken? = nil,
                capture: SignalCaptureInterval? = nil) {
        self.name = name; self.provenance = provenance
        self.number = number.flatMap { $0.isFinite ? $0 : nil }
        self.integer = integer; self.token = token; self.flag = flag; self.text = text
        self.units = units; self.capture = capture
        self.reason = number.map { !$0.isFinite } == true ? .nonFinite : reason
    }
}

/// RGB or Y/Cb/Cr components. Units/layout are declared by the containing observation.
public struct SignalComponents: Codable, Sendable, Equatable {
    public let first: Double
    public let second: Double
    public let third: Double
    public var isFinite: Bool { first.isFinite && second.isFinite && third.isFinite }
    public init(first: Double, second: Double, third: Double) {
        self.first = first; self.second = second; self.third = third
    }
}

public struct SignalIntegerComponents: Codable, Sendable, Equatable {
    public let first: Int64
    public let second: Int64
    public let third: Int64
    public init(first: Int64, second: Int64, third: Int64) {
        self.first = first; self.second = second; self.third = third
    }
}

/// Received values and calculated equivalents are separate fields. Never reconstruct received codes.
public struct SignalSampleEvidence: Codable, Sendable, Equatable {
    public let role: SignalToken
    public let ordinal: Int
    public let representation: SignalToken?
    public let declaredBitDepth: Int?
    public let receivedIntegers: SignalIntegerComponents?
    public let receivedValues: SignalComponents?
    public let effectiveRendererInput: SignalComponents?
    public let calculatedCodes: SignalIntegerComponents?
    public let geometry: NormalizedRectangle?
    public let fields: [SignalFieldEvidence]
    public let reason: SignalToken?
    public init(role: SignalToken, ordinal: Int, representation: SignalToken? = nil,
                declaredBitDepth: Int? = nil, receivedIntegers: SignalIntegerComponents? = nil,
                receivedValues: SignalComponents? = nil, effectiveRendererInput: SignalComponents? = nil,
                calculatedCodes: SignalIntegerComponents? = nil, geometry: NormalizedRectangle? = nil,
                fields: [SignalFieldEvidence] = [], reason: SignalToken? = nil) {
        self.role = role; self.ordinal = ordinal; self.representation = representation
        self.declaredBitDepth = declaredBitDepth; self.receivedIntegers = receivedIntegers
        self.receivedValues = receivedValues.flatMap { $0.isFinite ? $0 : nil }
        self.effectiveRendererInput = effectiveRendererInput.flatMap { $0.isFinite ? $0 : nil }
        self.calculatedCodes = calculatedCodes; self.geometry = geometry; self.fields = fields
        self.reason = receivedValues?.isFinite == false || effectiveRendererInput?.isFinite == false ? .nonFinite : reason
    }
}

/// One of source, app mapping, SDI frame or physical signal. Stages retain their own captured identities.
/// `fields` can describe layout/range/rounding, actual layer policy, headroom, and boundary availability.
public struct SignalStageEvidence: Codable, Sendable, Equatable {
    public let status: SignalToken
    public let provenance: SignalToken?
    public let reason: SignalToken?
    public let contentID: String?
    public let configurationIdentity: String?
    public let mappingIdentity: String?
    public let presentationIdentity: String?
    public let targetLifetime: String?
    public let drawSequence: UInt64?
    public let submittedAt: Double?
    public let presentedAt: Double?
    public let capture: SignalCaptureInterval?
    public let fields: [SignalFieldEvidence]
    public let samples: [SignalSampleEvidence]
    public let totalSampleCount: Int
    public let omittedSampleCount: Int
    public init(status: SignalToken = .unknown, provenance: SignalToken? = nil, reason: SignalToken? = nil,
                contentID: String? = nil, configurationIdentity: String? = nil, mappingIdentity: String? = nil,
                presentationIdentity: String? = nil, targetLifetime: String? = nil, drawSequence: UInt64? = nil,
                submittedAt: Double? = nil, presentedAt: Double? = nil, capture: SignalCaptureInterval? = nil,
                fields: [SignalFieldEvidence] = [], samples: [SignalSampleEvidence] = [], totalSampleCount: Int? = nil) {
        self.status = status; self.provenance = provenance; self.reason = reason
        self.contentID = contentID; self.configurationIdentity = configurationIdentity
        self.mappingIdentity = mappingIdentity; self.presentationIdentity = presentationIdentity
        self.targetLifetime = targetLifetime; self.drawSequence = drawSequence
        self.submittedAt = submittedAt.flatMap { $0.isFinite ? $0 : nil }
        self.presentedAt = presentedAt.flatMap { $0.isFinite ? $0 : nil }; self.capture = capture
        self.fields = fields; self.samples = Array(samples.prefix(64))
        self.totalSampleCount = max(totalSampleCount ?? samples.count, samples.count)
        self.omittedSampleCount = self.totalSampleCount - self.samples.count
    }
    func omittingDetails() -> Self {
        Self(status: status, provenance: provenance, reason: fields.isEmpty && samples.isEmpty ? reason : .payloadLimit, contentID: contentID,
             configurationIdentity: configurationIdentity, mappingIdentity: mappingIdentity,
             presentationIdentity: presentationIdentity, targetLifetime: targetLifetime, drawSequence: drawSequence,
             submittedAt: submittedAt, presentedAt: presentedAt, capture: capture,
             totalSampleCount: totalSampleCount)
    }
}
