# Changelog

All notable changes to PatternSpaceSDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows semantic versioning.

## [0.3.0] - 2026-06-03

### Added
- `display.list` — returns display inventory and selected display metadata
- `display.setPeakWhite` — sets Peak White for one display (authenticated, Pro-gated)
- `display.changed` — notification broadcast on display inventory, selection, or Peak White changes
- `DisplayEntry`, `DisplayListResult`, `PeakWhiteRange`, `SetPeakWhiteParams` Codable models in `PatternSpaceSDKCore`
- `PSErrorCode.displayNotFound`, `.peakWhiteOutOfRange`, `.notAuthorized` typed error codes
- `PatternSpaceClient.display` namespace with `list()` and `setPeakWhite(displayId:peakWhite:)`
- `PatternSpaceEvent.displayChanged(DisplayListResult)` — **source-breaking** for exhaustive switches; minor version bump signals this

### Notes
- `display.list` and `display.setPeakWhite` do not require the JSON source to be active
- `peakWhite` and `effectivePeakWhite` can differ when the stored value exceeds current display capability (non-destructive clamping)

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
