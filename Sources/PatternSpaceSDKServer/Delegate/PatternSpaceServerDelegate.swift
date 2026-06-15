// Sources/PatternSpaceSDKServer/Delegate/PatternSpaceServerDelegate.swift
import PatternSpaceSDKCore

/// Server-side integration point implemented by a PatternSpace host app.
///
/// `PatternSpaceServer` receives JSON-RPC requests and forwards validated
/// operations to this delegate. Write methods are invoked only while
/// `isSourceActive` is `true`.
public protocol PatternSpaceServerDelegate: AnyObject, Sendable {

    // MARK: Pattern write — only invoked when isSourceActive == true

    /// Displays an app-provided pattern by protocol identifier.
    func displayPattern(id: String) async throws

    /// Displays a full-screen solid color.
    func displayColor(_ color: PSColor, bitDepth: BitDepth) async throws

    /// Displays one or more normalized rectangles over a background color.
    func displayPatch(_ params: PatchParams) async throws

    /// Clears the current JSON protocol pattern.
    func clearDisplay() async throws

    // MARK: Read — always invoked

    /// Lists available patterns, optionally filtered by category and subcategory.
    func listPatterns(category: String?, subcategory: String?) async throws -> [PatternInfo]

    /// Returns metadata for a single pattern.
    func getPattern(id: String) async throws -> PatternInfo

    /// Returns static and configuration information about the active display.
    func deviceInfo() async throws -> DeviceInfo

    /// Returns runtime state for the host app.
    func deviceStatus() async throws -> DeviceStatus

    /// Returns protocol, route, and feature metadata for integrators.
    func capabilities() async throws -> CapabilitiesResult

    /// Returns display inventory and selected display metadata.
    func listDisplays() async throws -> DisplayListResult

    /// Sets Peak White for one display and returns the updated record.
    ///
    /// Display configuration writes do not require the JSON source to be active.
    func setPeakWhite(_ params: SetPeakWhiteParams) async throws -> DisplayEntry

    /// Lists available color-management modes for a display.
    func listColorManagementModes(displayId: String) async throws -> ColorManagementModeList

    /// Sets the host-global color-management mode when the display matches selected output.
    ///
    /// Display configuration writes do not require the JSON source to be active.
    func setColorManagementMode(_ params: SetColorManagementModeParams) async throws -> SetColorManagementModeResult

    /// Lists output color presets for a display.
    func listOutputColorPresets(displayId: String) async throws -> OutputColorPresetList

    /// Sets the host-global output color preset when the display matches selected output.
    ///
    /// Display configuration writes do not require the JSON source to be active.
    func setOutputColorPreset(_ params: SetOutputColorPresetParams) async throws -> SetOutputColorPresetResult

    // MARK: Source state

    /// Returns true when the JSON source is the currently selected PatternSourceSelection.
    var isSourceActive: Bool { get }

}

public extension PatternSpaceServerDelegate {
    func listOutputColorPresets(displayId: String) async throws -> OutputColorPresetList {
        OutputColorPresetList(displayId: displayId, selectedPresetId: nil, scope: .host, presets: [])
    }

    func setOutputColorPreset(_ params: SetOutputColorPresetParams) async throws -> SetOutputColorPresetResult {
        throw PSDispatchError(
            .outputColorPresetUnsupported,
            data: .object([
                "requestedPresetId": .string(params.presetId.rawValue),
                "supportedPresetIds": .array([]),
                "scope": .string(ColorManagementScope.host.rawValue),
                "reason": .string("unsupportedPlatform")
            ])
        )
    }
}
