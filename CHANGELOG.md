# Changelog

All notable changes to PatternSpaceSDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows semantic versioning.

## [0.7.0] - 2026-06-19

### Added
- `display.setMeasurementRange` server route, delegate hook, client method, params, and result schemas
- Additive `selectedMeasurementRange` fields on `DisplayEntry` and `DeviceStatus`

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.0`; PatternSpace JSON protocol is now `1.3`

### Removed
- Per-preset `measurementRange` from `OutputColorPresetConfig`; measurement range is host-global runtime state

## [0.6.0] - 2026-06-17

### Added
- Preset ID constants for three Linear HDR presets: `extLinearSRGBHDR`, `linearHDRP3D65`, `linearHDRBT2020`
- `OutputColorPresetFamily.linearHDR` convenience constant for clients reading Linear HDR preset metadata

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.6.0`; PatternSpace JSON protocol remains `1.2`
- Protocol documentation and README examples now describe Linear HDR presets and Peak White gating semantics

## [0.5.1] - 2026-06-17

### Added
- Convenience preset ID constants for `sdrReferenceP3D65Gamma22` and `sdrReferenceP3D65Gamma26`
- Open-string convenience constants for `OutputColorPresetTransfer.proPhotoROMM` and `OutputColorPresetInputEncoding.proPhotoROMM`

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.5.1`; PatternSpace JSON protocol remains `1.2`

## [0.5.0] - 2026-06-17

### Added
- `display.getOutputColorPreset` server route, client namespace method, delegate hook, params, and result schemas
- `OutputColorPresetSummary` for lightweight discovery and `OutputColorPresetConfig` for full self-describing preset configuration
- `catalogRevision` on both list and get preset responses, defined as an opaque host-catalog cache token
- Open-string preset metadata wrappers for family, gamut, white point, transfer, input encoding, dynamic range, tone mapping, measurement range, and implementation status

### Changed
- PatternSpace JSON protocol version is now `1.2`
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.5.0`
- `display.listOutputColorPresets` now returns lightweight summaries only; clients should call `display.getOutputColorPreset` when they need full color-science configuration
- Hosts must return full config for known presets even when the current display does not support them; unknown IDs remain `outputColorPresetUnsupported`

### Removed
- Legacy closed color-management mode API: `ColorManagementMode`, mode list/set schemas, delegate hooks, client methods, dispatcher routes, capability flag, and `colorManagementModeUnsupported`
- Legacy color-management fields from `DeviceStatus` and `DisplayEntry`; use output preset fields instead

### Migration
- Replace `display.listColorManagementModes` and `display.setColorManagementMode` with the output preset catalog flow: list summaries, fetch config for a selected ID, then set the preset
- Treat preset IDs and metadata values as open strings; SDK constants are conveniences, not a closed catalog
- Cache full configs by `(presetId, catalogRevision)` when useful
- Continue using `notAuthorized` (`-32009`) for Pro entitlement failures

## [0.4.1] - 2026-06-15

### Added
- Flexible output color preset schemas: `OutputColorPresetID`, `OutputColorPreset`, `OutputColorPresetList`, `SetOutputColorPresetParams`, and `SetOutputColorPresetResult`
- Additive `DisplayEntry` fields for `outputColorPresetId`, `supportedOutputColorPresetIds`, and `outputColorPresetImplementationStatus`
- Additive `DeviceStatus` fields for selected output preset and HDR diagnostics: EDR headroom, reference white, and clip-onset values
- `display.listOutputColorPresets` and `display.setOutputColorPreset` server routes and client display namespace methods
- `CapabilityFeatures.outputColorPresets`
- `PSErrorCode.outputColorPresetUnsupported`

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.4.1`
- `PatternSpaceServerDelegate` has default unsupported implementations for output preset routes, so existing hosts can adopt `0.4.1` without immediately implementing the new API

### Notes
- Preset IDs are open strings; clients should discover presets from the server instead of hardcoding a closed enum
- Unknown preset IDs reach `outputColorPresetUnsupported` instead of failing JSON parameter decoding
- Pro entitlement failures should continue to use `notAuthorized` (`-32009`)
- Legacy color-management fields remain optional and can be `null`/omitted when an HDR output preset has no `ColorManagementMode` equivalent

## [0.4.0] - 2026-06-15

### Added
- `PatternSpaceProtocolMetadata` with protocol version `1.1` and SDK version `0.4.0`
- `capabilities.list` route and `PatternSpaceClient.capabilities.list()` for protocol, app, SDK, namespace, feature, platform, and auth discovery
- Bonjour TXT metadata for `protocolVersion` and `authRequired`
- Richer optional `DeviceStatus` metadata: selected source/display, color-management state, profile resolution, auth mode, client count, app version/build, SDK version, and protocol version
- Color-management schemas: `ColorManagementMode`, `ColorManagementModeEntry`, `ColorManagementModeList`, `SetColorManagementModeParams`, and `SetColorManagementModeResult`
- Additive `DisplayEntry` color-management fields, with forward-compatible decoding for unknown keys and absent mode arrays
- `display.listColorManagementModes` and `display.setColorManagementMode` server routes and client display namespace methods
- `PSErrorCode.colorManagementModeUnsupported` and `.displaySelectionMismatch`
- Route-manifest coverage to keep `capabilities.list` namespaces aligned with dispatcher routes

### Changed
- PatternSpace JSON protocol version is now `1.1`
- `PatternSpaceServerDelegate` adds `capabilities()`, `listColorManagementModes(displayId:)`, and `setColorManagementMode(_:)` host hooks — **source-breaking** for server delegate conformers

### Notes
- `capabilities.list`, `display.listColorManagementModes`, and `display.setColorManagementMode` do not require the JSON source to be active after a WebSocket connection is established
- Unknown color-management mode strings return JSON-RPC `invalidParams`; known but unsupported modes return `colorManagementModeUnsupported`
- Display color-management writes are host-scoped in this release, so hosts should return the selected display that actually changed

## [0.3.0] - 2026-06-03

### Added
- `display.list` — returns display inventory and selected display metadata
- `display.setPeakWhite` — sets Peak White for one display (authenticated, Pro-gated)
- `display.changed` — notification broadcast on display inventory, selection, or Peak White changes
- `DisplayEntry`, `DisplayListResult`, `PeakWhiteRange`, `SetPeakWhiteParams` Codable models in `PatternSpaceSDKCore`
- `PSErrorCode.displayNotFound`, `.peakWhiteOutOfRange`, `.notAuthorized` typed error codes
- `PatternSpaceClient.display` namespace with `list()` and `setPeakWhite(displayId:peakWhite:)`
- `PatternSpaceEvent.displayChanged(DisplayListResult)` — **source-breaking** for exhaustive switches; minor version bump signals this
- `PatternSpaceServerDelegate.listDisplays()` and `setPeakWhite(_:)` host hooks — **source-breaking** for server delegate conformers
- Protocol documentation and README examples for the `display.*` methods

### Notes
- `display.list` and `display.setPeakWhite` do not require the JSON source to be active
- `peakWhite` and `effectivePeakWhite` can differ when the stored value exceeds current display capability (non-destructive clamping)
- `display.setPeakWhite` returns the updated `DisplayEntry` directly, not a wrapper object

## [0.2.1] - 2026-05-19

### Breaking changes

- `DeviceStatus`, `DeviceSnapshot`, and `ConnectionReadyParams` no longer include `connectedClients`. `PatternSpaceServer` enforces single-client behavior unconditionally, so the count carried no useful information for callers.
- Changed `PatternSpaceServer.init(token:delegate:connectionReady:)` so the `connectionReady` closure receives only `authenticated`; the previous `(Bool, Int) -> ConnectionReadyParams` closure is now `(Bool) -> ConnectionReadyParams`.

### Behavioral changes

- New WebSocket connections unconditionally drop any existing client before sending `connectionReady`.
- `sourceActive` in `DeviceStatus`, `DeviceSnapshot`, and `ConnectionReadyParams` is documented as a race-condition guard. In normal operation, source deactivation closes the socket.

### No changes

- JSON-RPC framing, auth handshake, method catalog, error codes, and protocol version remain unchanged.
- `PatternSpaceSDKClient` API is unchanged.

## [0.2.0] - 2026-05-18

### Changed

- Replaced `pattern.displayRectangle` with `pattern.displayPatch`.
- Replaced pixel rectangle coordinates with normalized display-space coordinates.
- Added multi-rectangle patch support with one shared background color.
- Added optional CalMAN-style area percentage `size` to `pattern.displayColor`.
- Removed `currentResolution` from `PatternSpaceServerDelegate`; patch placement no longer depends on client-visible screen resolution.

## [0.1.0] - 2026-05-18

### Added

- Initial Swift Package Manager package.
- `PatternSpaceSDKCore` product with JSON-RPC envelopes, JSON values, error codes, pattern models, device schemas, and events.
- `PatternSpaceSDKClient` product with Bonjour discovery, WebSocket transport, request correlation, reconnection, and typed pattern/device namespaces.
- `PatternSpaceSDKServer` product with TCP listener, WebSocket upgrade handling, manual frame codec, JSON-RPC dispatch, input validation, auth rejection, rate limiting, and event broadcast.
- Swift Testing coverage for core models, validation, dispatch, WebSocket upgrade, and WebSocket frames.
