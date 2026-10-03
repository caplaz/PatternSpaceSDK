# PatternSpace JSON Protocol

PatternSpaceSDK speaks a JSON-RPC 2.0 subset over WebSocket.

```text
ws://<host>:7878/patternspace
```

`/patternspace` is the canonical path, but the server accepts the upgrade on any
resource path (e.g. `/`) so that hostPort and Bonjour client endpoints — which
cannot carry a path — can connect. The bearer token is the authentication
boundary.

Bonjour service type:

```text
_patternspace._tcp
```

The server advertises `protocolVersion=1.3` and `authRequired=true|false` in the TXT record.

## Authentication

If the server is configured with a token, the HTTP upgrade request must include:

```http
Authorization: Bearer <token>
```

Invalid or missing credentials receive HTTP `401 Unauthorized`; valid clients receive `101 Switching Protocols`. When auth is required, unauthenticated clients are rejected during the WebSocket upgrade before JSON-RPC dispatch. Clients can still discover whether auth is required from the Bonjour TXT record.

## Envelopes

Requests use JSON-RPC 2.0 with a string or integer `id`. Notifications omit `id`.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "pattern.displayColor",
  "params": {
    "r": 1.0,
    "g": 0.0,
    "b": 0.0,
    "bitDepth": 10,
    "size": 10
  }
}
```

Success responses carry `result`; failures carry JSON-RPC errors with PatternSpace-specific codes where appropriate.

## Capabilities

### `capabilities.list`

Returns protocol, app, SDK, route, feature, platform, and auth metadata. Integrators should call this after connecting to discover the server's supported namespaces.

```json
{
  "jsonrpc": "2.0",
  "id": 0,
  "result": {
    "protocolVersion": "1.3",
    "app": { "name": "PatternSpace", "version": "1.2.0", "build": "1" },
    "sdkVersion": "1.0.0",
    "platform": "macOS",
    "authRequired": true,
    "namespaces": {
      "capabilities": ["list"],
      "device": ["info", "status"],
      "display": ["list", "setPeakWhite", "listOutputColorPresets", "getOutputColorPreset", "setOutputColorPreset", "setMeasurementRange"],
      "output": ["blank", "resume"],
      "pattern": ["display", "displayColor", "displayPatch", "clear", "list", "get"]
    },
    "features": {
      "events": true,
      "displayInventory": true,
      "peakWhiteControl": true,
      "outputColorPresets": true,
      "measurementRange": true,
      "catalogPatterns": true,
      "customICCBuilder": false,
      "httpBridge": false
    },
    "outputBlank": true
  }
}
```

`outputBlank` is a top-level optional flag (absent from older hosts). Call `output.*` only when it is `true`. The SDK route manifest always lists the `output` namespace, so hosts that do not implement blanking reply `methodNotFound` (`-32601`) and omit `outputBlank`.

## Pattern Methods

### `pattern.displayColor`

Displays an RGB color. By default the color fills the whole screen. When `size` is provided, it uses CalMAN-style screen area percentage and displays a centered patch over black.

```json
{
  "r": 1.0,
  "g": 1.0,
  "b": 1.0,
  "bitDepth": 10,
  "size": 10
}
```

Color channels are normalized `0.0...1.0`. `size` is optional, defaults to `100`, and must be in `(0, 100]`. A `size` of `10` means 10% of total screen area; the centered rectangle side length is `sqrt(size / 100)`.

### `pattern.displayPatch`

Displays one or more normalized rectangles over one background color. Rectangles are rendered in array order.

```json
{
  "background": { "r": 0.0, "g": 0.0, "b": 0.0 },
  "rectangles": [
    {
      "color": { "r": 1.0, "g": 1.0, "b": 1.0 },
      "x": 0.25,
      "y": 0.25,
      "width": 0.5,
      "height": 0.5
    }
  ],
  "bitDepth": 10
}
```

Rectangle coordinates are normalized display-space values. `(0, 0)` is the top-left of the active output and `(1, 1)` is the bottom-right. Each rectangle must fit inside the normalized display space. A patch may contain up to 64 rectangles.

### `pattern.clear`

Clears the active remote pattern.

```json
{}
```

### `pattern.list`

Lists built-in patterns, optionally filtered by category and subcategory.

```json
{
  "category": "color",
  "subcategory": "primary"
}
```

### `pattern.display`

Displays a built-in pattern by id.

```json
{
  "patternId": "color/red"
}
```

### `pattern.get`

Gets metadata for one built-in pattern.

```json
{
  "patternId": "color/red"
}
```

## Device Methods

### `device.info`

Returns static device information such as name, resolution, color format, bit depth, HDR mode, refresh rate, and output range.

### `device.status`

Returns runtime state: current pattern id, JSON source activity, selected source/display, profile resolution, auth mode, connected client count, app version/build, SDK version, protocol version, selected output preset, EDR headroom, reference-white, and clip-onset diagnostics. Decoders should ignore unknown additive fields.

When the host reports output ownership and blank state, `device.status` includes an optional `output` object with the [`OutputStatus`](#outputstatus) shape.

Protocol `1.2` no longer defines the legacy typed color-management mode fields. Hosts using output presets should report `outputColorPresetId` and `outputColorPresetImplementationStatus`.

## Display Methods

Display methods expose display inventory, Peak White control, and output color preset control. They are authenticated when the server requires a token, but they do not require the JSON source to be active.

### `display.list`

Returns display inventory and selected display metadata.

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "platform": "macOS",
    "selectedDisplayId": "69734272",
    "displays": [
      {
        "id": "69734272",
        "name": "Studio Display",
        "selected": true,
        "connection": "wired",
        "resolution": { "width": 5120, "height": 2880 },
        "refreshRate": 60,
        "colorSpaceName": "Display P3",
        "cgColorSpaceName": "kCGColorSpaceDisplayP3",
        "maximumPotentialEDR": 4.0,
        "maximumCurrentEDR": 2.0,
        "peakWhite": 4.0,
        "effectivePeakWhite": 2.0,
        "peakWhiteRange": { "minimum": 0.25, "maximum": 4.0 },
        "supportsPeakWhiteControl": false,
        "displayProfileResolved": true,
        "outputColorPresetId": "deviceNative",
        "supportedOutputColorPresetIds": ["deviceNative", "sdrReferenceSRGB", "hdrP3D65PQ", "hdrBT2020PQ", "extLinearSRGBHDR", "linearHDRP3D65", "linearHDRBT2020"],
        "outputColorPresetImplementationStatus": "native"
      }
    ]
  }
}
```

`platform` is `macOS` or `iOS`. `connection` is `builtIn`, `wired`, `airPlay`, or `unknown`. `peakWhite` is the stored EDR-relative Peak White value. `effectivePeakWhite` is the value currently in use after non-destructive clamping to the display's current capability.

Preset IDs are open strings. `supportedOutputColorPresetIds` is a quick display-entry summary; clients that need labels, groups, support reasons, or color-science details should call the preset catalog methods below.

### `display.setPeakWhite`

Sets Peak White for one display and returns the updated display entry directly.

```json
{
  "displayId": "69734272",
  "peakWhite": 3.0
}
```

`peakWhite` must be a finite number in the returned display's accepted `peakWhiteRange`. Out-of-range writes return `peakWhiteOutOfRange` with the rejected value and accepted bounds.

```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "error": {
    "code": -32008,
    "message": "Peak White out of range",
    "data": {
      "displayId": "69734272",
      "peakWhite": 12.0,
      "minimum": 0.25,
      "maximum": 4.0
    }
  }
}
```

Other display errors include `displayNotFound` (`-32007`) and `notAuthorized` (`-32009`).

### Output Color Preset Catalog

Output presets replace the old closed color-management mode API. The SDK defines convenience constants for known preset IDs, but IDs and metadata vocabularies are open strings. Adding a host preset should not require an SDK update. SDK `0.6.0` includes convenience constants for SDR Reference, HDR PQ, and Linear HDR presets, including `extLinearSRGBHDR`, `linearHDRP3D65`, and `linearHDRBT2020`.

Remote patches follow the active preset's input encoding exactly: SDR Reference decodes the configured transfer function, HDR PQ decodes normalized PQ signals, Linear HDR treats values as linear light, and Device Native passes values through raw. Built-in PatternSpace Library patterns are generated internally in linear light. They use the active preset's output color space when applicable, and Linear HDR presets apply Peak White. HDR PQ presets do not make Library patterns PQ-encoded; use HDR PQ when an external measurement workflow sends PQ patch values.

`catalogRevision` is an opaque cache token sourced from the host catalog. It is identical across `display.listOutputColorPresets` and `display.getOutputColorPreset` while the catalog is unchanged, and it changes whenever the preset set, summary metadata, or full config for any preset changes. Clients may cache full configs by `(presetId, catalogRevision)`.

### `display.listOutputColorPresets`

Returns lightweight preset summaries for UI/discovery.

```json
{
  "displayId": "69734272"
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 11,
  "result": {
    "displayId": "69734272",
    "selectedPresetId": "hdrBT2020PQ",
    "scope": "host",
    "catalogRevision": "2026-06-17.1",
    "presets": [
      {
        "id": "hdrBT2020PQ",
        "label": "BT.2020 PQ",
        "group": "hdr",
        "family": "hdrReference",
        "implementationStatus": "native",
        "supported": true,
        "requiresPro": true
      }
    ]
  }
}
```

The list result intentionally omits full config fields such as gamut, transfer, EDR diagnostics, and input encoding. Call `display.getOutputColorPreset` for those.

### `display.getOutputColorPreset`

Returns the full self-describing config for a known preset.

```json
{
  "displayId": "69734272",
  "presetId": "hdrBT2020PQ"
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 12,
  "result": {
    "displayId": "69734272",
    "catalogRevision": "2026-06-17.1",
    "preset": {
      "id": "hdrBT2020PQ",
      "label": "BT.2020 PQ",
      "group": "hdr",
      "family": "hdrReference",
      "gamut": "bt2020",
      "whitePoint": "d65",
      "transfer": "pqSt2084",
      "dynamicRange": "hdr",
      "toneMapping": "none",
      "inputEncoding": "pqSt2084",
      "implementationStatus": "native",
      "supported": true,
      "requiresPro": true,
      "layerColorSpace": "extendedLinearITUR_2020",
      "edrHeadroomRequired": 2.0,
      "edrHeadroomPotential": 4.0,
      "edrHeadroomCurrent": 2.0,
      "edrHeadroomReference": 1.0,
      "referenceWhiteNits": 100.0,
      "referenceWhiteNitsSource": "defaultCalibration100",
      "peakLuminanceNits": 200.0,
      "clipOnsetNits": 200.0,
      "clipOnsetPQSignal": 0.579
    }
  }
}
```

Hosts must return the config for any known preset, even when the current display cannot use it. In that case the preset config reports `supported: false`, an implementation status such as `insufficientHeadroom`, and an optional `unsupportedReason`. Throw `outputColorPresetUnsupported` only for genuinely unknown preset IDs.

Measurement range is host-global runtime state, not an intrinsic preset field.
Read the effective value from `selectedMeasurementRange` on `DisplayEntry` or
`DeviceStatus`.

### `display.setOutputColorPreset`

Sets the host-global output color preset and returns the selected display that actually changed.

```json
{
  "displayId": "69734272",
  "presetId": "hdrBT2020PQ"
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "result": {
    "scope": "host",
    "selectedPresetId": "hdrBT2020PQ",
    "selectedDisplayId": "69734272",
    "display": {
      "id": "69734272",
      "name": "Studio Display",
      "selected": true,
      "connection": "wired",
      "resolution": { "width": 5120, "height": 2880 },
      "maximumPotentialEDR": 4.0,
      "maximumCurrentEDR": 2.0,
      "peakWhite": 3.0,
      "effectivePeakWhite": 2.0,
      "peakWhiteRange": { "minimum": 0.25, "maximum": 4.0 },
      "supportsPeakWhiteControl": false,
      "outputColorPresetId": "hdrBT2020PQ",
      "supportedOutputColorPresetIds": ["deviceNative", "sdrReferenceSRGB", "hdrP3D65PQ", "hdrBT2020PQ", "extLinearSRGBHDR", "linearHDRP3D65", "linearHDRBT2020"],
      "outputColorPresetImplementationStatus": "native"
    }
  }
}
```

Unknown preset IDs return `outputColorPresetUnsupported` (`-32012`) with `requestedPresetId`, `supportedPresetIds`, `scope`, and `reason` in error data. Known-but-unsupported presets are discoverable via `getOutputColorPreset`; writes to them also fail with `outputColorPresetUnsupported`. Pro entitlement failures use `notAuthorized` (`-32009`). If a host requires the write target to match selected output, mismatches return `displaySelectionMismatch` (`-32011`).

### `display.setMeasurementRange`

Sets the host-global measurement range to the open-string value `full` or
`legal` and returns the effective selected range plus the updated display.

```json
{
  "displayId": "69734272",
  "measurementRange": "legal"
}
```

```json
{
  "scope": "host",
  "selectedMeasurementRange": "legal",
  "selectedDisplayId": "69734272",
  "display": {
    "id": "69734272",
    "selectedMeasurementRange": "legal"
  }
}
```

Legal range assumes full-range source values. Do not legal-encode in both the
source and PatternSpace, or the signal will be encoded twice.

## Output Methods

Output methods blank and restore the host output on purpose (for example, black between measurements while a calibration run is paused) and report who owns the content underneath. They have the same trust boundary as the `pattern.*` write methods: the connection must have passed token authentication, and the JSON source must be active (`sourceNotActive`, `-32005`, otherwise). The server attaches the sending connection's identity to each request; it is never read from params, and requests from an evicted or closed connection cannot change output.

Neither method takes parameters. `params` may be absent, `{}`, or `[]`. Non-empty params, `null`, and scalar values return `invalidParams` (`-32602`).

### `output.blank`

Blanks the output and returns the resulting [`OutputStatus`](#outputstatus).

```json
{ "jsonrpc": "2.0", "id": 20, "method": "output.blank" }
```

```json
{
  "jsonrpc": "2.0",
  "id": 20,
  "result": {
    "owner": "jsonClient",
    "ownerConnected": true,
    "blankRequester": "jsonClient",
    "blanked": "remote",
    "blankPending": false,
    "failure": null,
    "idleBlankSeconds": null,
    "epoch": "7C9E6679-7425-40DE-944B-E07FC1F90AE7",
    "revision": 42
  }
}
```

- The response is sent after the host confirms the blank on the selected output. Repeated calls while a blank is pending join that attempt; calls while already blanked are idempotent.
- If newer output supersedes the blank before it is confirmed (for example, a new patch from the owning controller), the call succeeds with the current status, which may show no blank or a pending blank for a new target. Superseded is not a failure; read the returned status rather than assuming black.
- If the blank failed or the selected output's state is unknown, the call fails with `outputNotConfirmed` (`-32013`).

### `output.resume`

Cancels a pending or active blank, restores the underlying content, and returns the resulting `OutputStatus` after restoration is submitted. When nothing is blanked it is a no-op that returns the current status, unless the output state is unknown, which returns `outputNotConfirmed` (`-32013`). Neither method clears an unknown-output state; that requires explicit recovery on the host.

### Success after supersession

A success response from any output write (`pattern.*` or `output.*`) means the host accepted the request. On SDI outputs it does not guarantee the frame was physically emitted: an accepted patch can be superseded by newer output before emission. Clients that need to know what is currently on screen should read the latest `OutputStatus`.

### `OutputStatus`

| Field | Type | Meaning |
| --- | --- | --- |
| `owner` | string | Owner of the underlying content, not the blank requester: `none`, `colourSpace`, `calman`, `pGenerator`, `jsonClient`, or `local`. |
| `ownerConnected` | bool | Whether the exact connection that produced the content is still active. |
| `blankRequester` | string or null | Producer that requested the pending or active blank (same vocabulary as `owner`); `null` outside a pending or active blank. |
| `blanked` | string or null | `manual`, `idle`, or `remote`, set only after the blank is confirmed; `null` while pending or when not blanked. |
| `blankPending` | bool | A blank has been requested but not yet confirmed. |
| `failure` | string or null | `notPresented` (the blank never reached the selected display) or `outputUnknown` (the selected output's state is unknown and requires explicit recovery); `null` otherwise. Failure takes priority over retained content: retained content is intent, not proof of physical output. |
| `idleBlankSeconds` | integer or null | Host idle-blank interval in seconds; `null` when idle blank is off. |
| `epoch` | string | Opaque UUID minted each time the host server starts. Epochs have no order; never compare them except for equality. |
| `revision` | integer | Status revision, monotonic within an `epoch` for the life of that server (not reset per client connection). |

The SDK encodes absent optional fields as explicit `null`; decoders accept either `null` or a missing key.

Ordering rules for clients:

- `revision` orders statuses only within the same `epoch`. A different `epoch` means the host server restarted; resynchronize (for example, call `device.status`) rather than comparing values.
- After `connectionReady`, apply a status from an event or a current-connection RPC result only if its `epoch` matches the handshake and its `revision` is greater than the last one applied. Discard results of requests sent on an earlier connection.
- `epoch` and `revision` do not identify a client connection.

`OutputStatus` appears as:

- the result of `output.blank` and `output.resume`;
- optional `output` on `device.status`;
- optional `output` on the `device.statusChanged` payload, which the host broadcasts on every status revision;
- optional `output` on `connectionReady`.

The `output` field is absent from hosts that do not report it.

## Errors

PatternSpace-specific JSON-RPC error codes:

| Code | Name | Meaning |
| --- | --- | --- |
| `-32002` | `patternNotFound` | Unknown pattern id. |
| `-32003` | `displayError` | The host failed to display the requested pattern. |
| `-32004` | `invalidBitDepth` | Unsupported bit depth. |
| `-32005` | `sourceNotActive` | The JSON source is not the active source. |
| `-32006` | `rateLimitExceeded` | Too many requests in the current rate-limit window. |
| `-32007` | `displayNotFound` | Unknown display id. |
| `-32008` | `peakWhiteOutOfRange` | Peak White outside the accepted range. |
| `-32009` | `notAuthorized` | Not authorized, including Pro entitlement failures. |
| `-32011` | `displaySelectionMismatch` | Write target does not match the selected output. |
| `-32012` | `outputColorPresetUnsupported` | Unknown or unsupported output color preset. |
| `-32013` | `outputNotConfirmed` | Output blank failed, or the selected output state is unknown. |

Standard JSON-RPC codes (`-32700`, `-32600`, `-32601`, `-32602`, `-32603`) keep their usual meanings.

## Notifications

### `connectionReady`

Sent after a successful WebSocket upgrade. The server accepts one client at a time. A new successful WebSocket upgrade drops any existing client before `connectionReady` is sent to the new client. The payload may include an optional `output` [`OutputStatus`](#outputstatus), which establishes the status `epoch` for the connection.

The Swift client fences delivery by connection: no event from a replaced socket is delivered after the new connection's `connectionReady`.

### `pattern.changed`

Sent when the displayed pattern changes.

### `device.statusChanged`

Sent when device state changes. The payload may include an optional `output` [`OutputStatus`](#outputstatus).

### `display.changed`

Sent when display inventory, selected display, Peak White values, or output preset fields change. The payload has the same shape as a `display.list` result.

```json
{
  "jsonrpc": "2.0",
  "method": "display.changed",
  "params": {
    "platform": "macOS",
    "selectedDisplayId": "69734272",
    "displays": []
  }
}
```

## Limits

- Maximum HTTP upgrade header size: 16 KiB
- Maximum WebSocket payload size: 65,536 bytes
- Client frames must be masked
- Fragmented frames are not accepted in the initial implementation
