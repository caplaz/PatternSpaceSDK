# Changelog

All notable changes to PatternSpaceSDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows semantic versioning.

## [1.1.0] - 2026-10-09

### Added
- Optional `device.signalSnapshot` read route and `DeviceNamespace.signalSnapshot()` returning schema-1 immutable evidence separately from connection-bound probe authorization. The delegate receives the authenticated `OutputRequestContext`; reads remain available while the JSON source is inactive.
- Optional `pattern.displayProbe` route and `PatternNamespace.displayProbe(_:)` carrying the existing patch shape plus a bounded opaque `expectedContextGuard`. The SDK reuses ordinary patch validation and forwards guard/context to the host for atomic authorization and admission. It never falls back to `displayPatch`.
- Typed source samples, scalar stage observations, separate accepted/published identities, draw/mapping/presentation identities, capture intervals, explicit unknown/omission reasons, and forward-compatible open tokens. Evidence excludes guard and packed frame buffers. Encoded responses are bounded to 256 KiB; each stage retains at most 64 samples with explicit omitted counts. Oversized optional details are marked omitted; oversized identity fails safely.
- Default unsupported delegate hooks and `supportsSignalSnapshot` / `supportsSignalProbe` opt-ins preserve 1.0.0 conformers. Optional `CapabilityFeatures.signalSnapshot` / `signalProbe` have trailing initializer defaults and decode absent from older hosts.

### Changed
- `capabilities.list` filters only unsupported new routes/flags, preserving all existing namespace entries. Unsupported new methods return method-not-found.
- `PatternSpaceProtocolMetadata.sdkVersion` is now `1.1.0`; JSON protocol remains `1.3`. Existing routes, device bit-depth meaning, ACK behavior and global session timeout behavior remain unchanged.

### Fixed
- Both client transports now accept the full 256 KiB SDK response bound, so valid signal snapshots larger than 64 KiB work on native Network.framework endpoints as well as URLSession endpoints. Server incoming request limits remain unchanged.
- Invalid mandatory capture timestamps fail validation rather than being replaced with zero. Unsupported evidence schema versions fail typed validation before evidence or probe authorization is decoded.

### Host integration
- Guards belong to the authenticated connection and stable expected target/configuration/ownership context, independent of snapshot revisions and new patches. Historical responses must have no authorization; stable Refresh must not rotate a current guard. Stale context uses `displayError`, a different connection uses `notAuthorized`, inactive source uses `sourceNotActive`, malformed guard uses `invalidParams`.
- Share only evidence and apply host export redaction to identifiers/optional descriptions. The SDK does not inspect OS profiles, calculate SDI packing, attest physical transport, or supply a per-request timeout.

## [1.0.0] - 2026-10-03

### Added
- `output.blank` and `output.resume` server routes under a new `output` namespace (listed in `JSONRPCDispatcher.routeManifest` and therefore in `capabilities.list`), with required delegate hooks `blankOutput(context:)` and `resumeOutput(context:)`. Both return the resulting `OutputStatus`; both require an authenticated connection and an active JSON source (`sourceNotActive` otherwise), exactly like the `pattern.*` write methods.
- `OutputStatus` schema with `owner`, `ownerConnected`, `blankRequester`, `blanked`, `blankPending`, `failure`, `idleBlankSeconds`, `epoch`, and `revision`, plus the enums `PSOutputOwner`, `PSOutputBlankReason`, and `PSOutputFailure`. Absent optional fields are encoded as explicit JSON `null`; decoders accept either a missing key or `null`.
- Optional `output: OutputStatus?` on `DeviceStatus` (`device.status`), `DeviceSnapshot` (`device.statusChanged`), and `ConnectionReadyParams` (`connectionReady`). It decodes as `nil` from hosts that do not report it.
- `CapabilitiesResult.outputBlank: Bool?` so clients can detect blank support before calling `output.*`; `nil` from older hosts.
- `PSErrorCode.outputNotConfirmed` (`-32013`) for a blank that failed or an output whose state is unknown.
- `OutputRequestContext` carrying the server-minted `clientID` of the authenticated connection that sent an output-write request. It is captured at dispatch and never read from JSON params.
- `PatternSpaceServer.onClientConnected: (UUID) -> Void`, delivered once per authenticated client when it becomes the active client, with the same identity carried by its `OutputRequestContext`.
- `ClientDisconnectReason` (`closed`, `evicted`, `serverStopped`).
- Client `client.output.blank()` and `client.output.resume()` via the new `OutputNamespace`.

### Changed
- **BREAKING:** The six output-write delegate methods are now required context-bearing methods with no default implementations and no context-free overloads: `displayPattern(id:context:)`, `displayColor(_:bitDepth:context:)`, `displayPatch(_:context:)`, `clearDisplay(context:)`, `blankOutput(context:)`, and `resumeOutput(context:)`. Hosts must compare the context with their current connection before mutating output so requests from an evicted or closed client cannot change output. Hosts without blank support must throw `PSDispatchError(.methodNotFound)` from `blankOutput`/`resumeOutput` and omit `CapabilitiesResult.outputBlank`.
- **BREAKING:** `JSONRPCDispatcher.dispatch(_:)` is now `dispatch(_:context:)`; output writes forward the context to the delegate and read handlers ignore it.
- **BREAKING:** `PatternSpaceServer.onClientDisconnected` is now `(UUID, ClientDisconnectReason) -> Void` and is delivered exactly once for every client previously reported to `onClientConnected`, regardless of how many clients remain. On replacement the evicted client's `.evicted` callback is delivered before the replacement's `onClientConnected`; `stop()` reports `.serverStopped` for every client not yet reported. Rejected (unauthenticated) sockets never produce either callback, and connections accepted after `stop()` are fenced out.
- Lifecycle callbacks are serialized on an internal queue in lifecycle order. Callbacks triggered by `stop()` run synchronously on the thread calling `stop()` after any in-progress callback finishes. Keep callbacks short and non-blocking (hop to your own actor or queue) and never call `DispatchQueue.main.sync` from one, or a `stop()` on the main thread will deadlock.
- `output.blank` and `output.resume` accept absent params, `{}`, or `[]`; non-empty params, `null`, and scalar params return `invalidParams`.
- The client transport now fences message delivery by connection: connection replacement, identity validation, disconnect reporting, and message delivery share one serialization boundary, so no event from an old socket can be yielded after the new connection's `connectionReady`. This applies to both the URLSession and Network.framework transports.
- `PatternSpaceProtocolMetadata.sdkVersion` is now `1.0.0`; PatternSpace JSON protocol remains `1.3` (the `output` namespace is additive and discoverable through `capabilities.list` and `outputBlank`).

### Fixed
- Pending JSON-RPC calls now fail asynchronously when the connection drops, including when the `PatternSpaceClient` has already been released, instead of leaving awaiting callers suspended.
- Native WebSocket close frames and send errors now end the socket and trigger auto-reconnect, rather than leaving the client attached to a dead connection.

### Migration
- Add a `context: OutputRequestContext` parameter to `displayPattern`, `displayColor`, `displayPatch`, and `clearDisplay`, and implement `blankOutput(context:)` and `resumeOutput(context:)` (throw `methodNotFound` if unsupported).
- Replace `onClientDisconnected = { ... }` closures with the `(UUID, ClientDisconnectReason)` signature and track the active client with `onClientConnected`.
- Pass a context to direct `JSONRPCDispatcher.dispatch` callers (for example in tests): `dispatch(data, context: OutputRequestContext(clientID: UUID()))`.

## [0.7.6] - 2026-09-10

### Fixed
- Made the WebSocket client integration test compatible with the Swift Testing version used by GitHub Actions. `TaskGroup.next()` is mutating and cannot be passed through that runner's `#require` macro; the test now unwraps its result with ordinary `guard` handling.

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.6`; PatternSpace JSON protocol remains `1.3`.

## [0.7.5] - 2026-09-10

### Fixed
- Explicit host/IP connections now use `URLSessionWebSocketTask` rather than `NWProtocolWebSocket`. On macOS 26, the latter could abort during the WebSocket upgrade against the PatternSpace server even while the server was listening and standards-compliant WebSocket clients connected successfully. Bonjour-discovered services retain the native Network.framework transport, which continues to resolve and connect correctly.
- Explicit `PatternSpaceClient.disconnect()` now fails pending JSON-RPC requests, rather than leaving an awaiting caller suspended after the transport has been closed.

### Changed
- Added a client/server integration test that exercises an authenticated `device.status` request over a real loopback WebSocket connection.
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.5`; PatternSpace JSON protocol remains `1.3`.

## [0.7.4] - 2026-06-23

### Fixed
- `WebSocketFrameCodec.decode` now decodes the second and later frames on a connection. It indexed with absolute `Data` offsets while comparing against `Data.count`, and returned `consumed` as an absolute index rather than a byte count. Because `Data` keeps a non-zero `startIndex` after `removeFirst(_:)`, every frame after the first decoded as perpetually `.incomplete`, so a client sending more than one request on a single connection would hang waiting for a response that was never dispatched. Decoding is now fully relative to `startIndex` and `consumed` is a true byte count. Single-request connections were unaffected (their buffers always started at index 0), which is why this only surfaced with multi-request sessions.

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.4`; PatternSpace JSON protocol remains `1.3`.

## [0.7.3] - 2026-06-23

### Fixed
- `PatternSpaceClient` now emits `.connectionFailed` for clean server-side closes (WebSocket close frame, nil error), not only for transport errors. Previously a clean close was silent — the event stream yielded nothing, leaving UI consumers (e.g. the iOS Remote tab) stuck showing "Connected" while the client was silently retrying. With this fix any unintentional disconnect, clean or error, surfaces as `.connectionFailed` so consumers can transition to a failure state immediately. Auto-reconnect still fires; if the server comes back the next `connectionReady` notification returns the consumer to connected.
- `PatternSpaceClientError` now conforms to `LocalizedError`, providing a readable `errorDescription` ("The server closed the connection") instead of the default Swift error description.

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.3`; PatternSpace JSON protocol remains `1.3`.

## [0.7.2] - 2026-06-23

### Fixed
- `PatternSpaceServer` now fires `onClientDisconnected` when the last active (upgraded) client disconnects. Previously the server silently removed the client from its tracking dict with no notification to the host, leaving the host app stuck in a "connected" state until a new client connected or the server restarted. The callback is suppressed when `stop()` drives the close (server shutdown already sets status to idle) and when a client is evicted by a new one (the new client is already active).

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.2`; PatternSpace JSON protocol remains `1.3`.

## [0.7.1] - 2026-06-23

### Fixed
- `PatternSpaceServer` now responds to WebSocket upgrade requests. Each incoming connection was released as soon as it was accepted — before its HTTP upgrade was processed — so the handshake never completed and clients timed out with no response. Connections are now retained until they upgrade or close.
- WebSocket upgrades are accepted on any resource path. `NWProtocolWebSocket` clients connecting through a hostPort or Bonjour service endpoint upgrade against `/` (such endpoints cannot carry a path), which the server previously rejected with `400 Bad Request`. The canonical path remains `/patternspace`, and the bearer token — not the path — stays the authentication boundary.

### Changed
- `PatternSpaceProtocolMetadata.sdkVersion` is now `0.7.1`; PatternSpace JSON protocol remains `1.3`.

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
