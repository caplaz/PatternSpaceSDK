// Sources/PatternSpaceSDKCore/Models/OutputSchemas.swift
import Foundation

/// Producer that owns the content currently underlying the host output.
public enum PSOutputOwner: String, Codable, Sendable, Equatable, CaseIterable {
    case none, colourSpace, calman, pGenerator, jsonClient, local
}

/// Why the host output is blanked.
public enum PSOutputBlankReason: String, Codable, Sendable, Equatable, CaseIterable {
    case manual, idle, remote
}

/// Why the most recent blank could not be confirmed.
public enum PSOutputFailure: String, Codable, Sendable, Equatable, CaseIterable {
    /// The blank was never presented on the selected display.
    case notPresented

    /// The selected output's state is unknown and requires explicit recovery.
    case outputUnknown
}

/// Output ownership and blank state reported by `output.blank`, `output.resume`,
/// `device.status`, `device.statusChanged`, and `connectionReady`.
///
/// `revision` orders statuses only within the same `epoch`. Epochs are opaque
/// UUID strings minted each time the host server starts and have no ordering.
public struct OutputStatus: Codable, Sendable, Equatable {
    /// Owner of the underlying content (not the blank requester).
    public let owner: PSOutputOwner

    /// Whether the exact connection that produced the content is still active.
    public let ownerConnected: Bool

    /// Producer that requested the pending or active blank; nil otherwise.
    public let blankRequester: PSOutputOwner?

    /// Reason for a confirmed blank; nil while pending or when not blanked.
    public let blanked: PSOutputBlankReason?

    /// Whether a blank has been requested but not yet confirmed.
    public let blankPending: Bool

    /// Current blank failure, if any.
    public let failure: PSOutputFailure?

    /// Idle-blank interval in seconds; nil when idle blank is off.
    public let idleBlankSeconds: Int?

    /// Opaque host server epoch (a UUID string).
    public let epoch: String

    /// Monotonic status revision within `epoch`.
    public let revision: UInt64

    /// Creates an output status value.
    public init(
        owner: PSOutputOwner,
        ownerConnected: Bool,
        blankRequester: PSOutputOwner?,
        blanked: PSOutputBlankReason?,
        blankPending: Bool,
        failure: PSOutputFailure?,
        idleBlankSeconds: Int?,
        epoch: String,
        revision: UInt64
    ) {
        self.owner = owner
        self.ownerConnected = ownerConnected
        self.blankRequester = blankRequester
        self.blanked = blanked
        self.blankPending = blankPending
        self.failure = failure
        self.idleBlankSeconds = idleBlankSeconds
        self.epoch = epoch
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case owner, ownerConnected, blankRequester, blanked, blankPending
        case failure, idleBlankSeconds, epoch, revision
    }

    /// Encodes absent optional fields as explicit JSON `null`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(owner, forKey: .owner)
        try container.encode(ownerConnected, forKey: .ownerConnected)
        try container.encode(blankRequester, forKey: .blankRequester)
        try container.encode(blanked, forKey: .blanked)
        try container.encode(blankPending, forKey: .blankPending)
        try container.encode(failure, forKey: .failure)
        try container.encode(idleBlankSeconds, forKey: .idleBlankSeconds)
        try container.encode(epoch, forKey: .epoch)
        try container.encode(revision, forKey: .revision)
    }
}
