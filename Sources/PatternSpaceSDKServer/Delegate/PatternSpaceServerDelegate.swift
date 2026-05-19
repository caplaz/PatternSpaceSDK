// Sources/PatternSpaceSDKServer/Delegate/PatternSpaceServerDelegate.swift
import PatternSpaceSDKCore

/// PatternSpace.app implements this protocol and passes itself to PatternSpaceServer.
/// The dispatcher calls write methods only when isSourceActive returns true.
public protocol PatternSpaceServerDelegate: AnyObject, Sendable {

    // MARK: Write — only invoked when isSourceActive == true

    func displayPattern(id: String) async throws
    func displayColor(_ color: PSColor, bitDepth: BitDepth) async throws
    func displayRectangle(_ params: RectangleParams) async throws
    func clearDisplay() async throws

    // MARK: Read — always invoked

    func listPatterns(category: String?, subcategory: String?) async throws -> [PatternInfo]
    func getPattern(id: String) async throws -> PatternInfo
    func deviceInfo() async throws -> DeviceInfo
    func deviceStatus() async throws -> DeviceStatus

    // MARK: Source state

    /// Returns true when the JSON source is the currently selected PatternSourceSelection.
    var isSourceActive: Bool { get }

    /// Current display resolution — used for rectangle bounds validation.
    var currentResolution: Resolution { get }
}
