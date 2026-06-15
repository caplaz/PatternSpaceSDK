# PatternSpace JSON Protocol

PatternSpaceSDK speaks a JSON-RPC 2.0 subset over WebSocket.

```text
ws://<host>:7878/patternspace
```

Bonjour service type:

```text
_patternspace._tcp
```

The server advertises `protocolVersion=1.1` and `authRequired=true|false` in the TXT record.

## Authentication

If the server is configured with a token, the HTTP upgrade request must include:

```http
Authorization: Bearer <token>
```

Invalid or missing credentials receive HTTP `401 Unauthorized`; valid clients receive `101 Switching Protocols`.

When auth is required, unauthenticated clients are rejected during the WebSocket upgrade before JSON-RPC dispatch. Clients can still discover whether auth is required from the Bonjour TXT record.

## Request Envelope

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

`id` may be a string or integer. Notifications omit `id`.

## Success Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": true
}
```

## Error Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params"
  }
}
```

## Methods

### Patch Color Methods

These methods drive ad hoc calibration patches. They do not require the client to know the app's built-in pattern catalog.

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

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {}
}
```

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

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {}
}
```

### `pattern.clear`

Clears the active remote pattern.

```json
{}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {}
}
```

### Existing Pattern List Methods

These methods let clients discover and display patterns that PatternSpace already ships in its catalog.

### `pattern.list`

Lists available patterns, optionally filtered by category and subcategory.

```json
{
  "category": "color",
  "subcategory": "primary"
}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "patterns": [
      {
        "id": "color/red",
        "name": "Red",
        "category": "color",
        "subcategory": "primary"
      },
      {
        "id": "checks/checkerboard",
        "name": "Checkerboard",
        "category": "checks",
        "subcategory": "layout"
      }
    ]
  }
}
```

### `pattern.display`

Displays a named pattern by id.

```json
{
  "patternId": "color/red"
}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "patternId": "color/red"
  }
}
```

### `pattern.get`

Gets metadata for one pattern.

```json
{
  "patternId": "color/red"
}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "id": "color/red",
    "name": "Red",
    "category": "color",
    "subcategory": "primary"
  }
}
```

### `device.info`

Returns static device information such as name, resolution, color format, bit depth, HDR mode, refresh rate, and output range.

### `capabilities.list`

Returns protocol, app, SDK, route, feature, platform, and auth metadata. Integrators should call this after connecting to discover the server's supported namespaces.

```json
{}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 0,
  "result": {
    "protocolVersion": "1.1",
    "app": { "name": "PatternSpace", "version": "1.1.0", "build": "1" },
    "sdkVersion": "0.4.0",
    "platform": "macOS",
    "authRequired": true,
    "namespaces": {
      "capabilities": ["list"],
      "device": ["info", "status"],
      "display": ["list", "setPeakWhite", "listColorManagementModes", "setColorManagementMode"],
      "pattern": ["display", "displayColor", "displayPatch", "clear", "list", "get"]
    },
    "features": {
      "events": true,
      "displayInventory": true,
      "peakWhiteControl": true,
      "colorManagementModes": true,
      "measurementRange": false,
      "catalogPatterns": true,
      "customICCBuilder": false,
      "httpBridge": false
    }
  }
}
```

### `device.status`

Returns current status, including active pattern id and whether the JSON source is active. Protocol `1.1` adds optional integration metadata such as selected source, selected display, color-management mode/status/scope, profile resolution, auth mode, connected client count, app version/build, SDK version, and protocol version. Decoders should ignore unknown additive fields.

### Display Methods

These methods expose display inventory, Peak White control, and color-management mode control. They are authenticated when the server requires a token, but they do not require the JSON source to be active.

### `display.list`

Returns display inventory and selected display metadata.

```json
{}
```

Sample response:

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
        "peakWhiteRange": {
          "minimum": 0.25,
          "maximum": 4.0
        },
        "supportsPeakWhiteControl": true,
        "colorManagementMode": "deviceNative",
        "supportedColorManagementModes": ["deviceNative", "managedSRGB", "managedDisplayP3", "managedRec2020"],
        "colorManagementImplementationStatus": "native",
        "colorManagementScope": "host",
        "displayProfileResolved": true
      }
    ]
  }
}
```

`platform` is `macOS` or `iOS`. `connection` is `builtIn`, `wired`, `airPlay`, or `unknown`; `unknown` is reserved for defensive fallback when a host cannot classify a display. On iOS, external outputs report `wired` for USB/HDMI-style connections or `airPlay` for AirPlay routes.

`peakWhite` is the stored EDR-relative Peak White value. `effectivePeakWhite` is the value currently in use after non-destructive clamping to the display's current capability, so it can be lower than `peakWhite`.

Color-management fields are additive. On macOS, `colorManagementMode` is host-global, so every display entry reports the same mode and `colorManagementScope: "host"`. Per-entry fields such as `displayProfileResolved` are computed for that display. On platforms without writable color-management support, hosts may report `colorManagementMode: null`, `supportedColorManagementModes: []`, and `colorManagementImplementationStatus: "unsupported"`.

### `display.setPeakWhite`

Sets Peak White for one display and returns the updated display entry directly.

```json
{
  "displayId": "69734272",
  "peakWhite": 3.0
}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "result": {
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
    "peakWhite": 3.0,
    "effectivePeakWhite": 2.0,
    "peakWhiteRange": {
      "minimum": 0.25,
      "maximum": 4.0
    },
    "supportsPeakWhiteControl": true,
    "colorManagementMode": "deviceNative",
    "supportedColorManagementModes": ["deviceNative", "managedSRGB", "managedDisplayP3", "managedRec2020"],
    "colorManagementImplementationStatus": "native",
    "colorManagementScope": "host",
    "displayProfileResolved": true
  }
}
```

`peakWhite` must be a finite number in the returned display's accepted `peakWhiteRange`. Out-of-range writes return `peakWhiteOutOfRange` with the rejected value and accepted bounds:

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

### `display.listColorManagementModes`

Returns the advertised color-management modes for a display and the selected host-global mode.

```json
{
  "displayId": "69734272"
}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 9,
  "result": {
    "displayId": "69734272",
    "selectedMode": "deviceNative",
    "scope": "host",
    "modes": [
      {
        "id": "deviceNative",
        "label": "Device Native",
        "layerColorSpace": "displayProfile",
        "inputEncoding": "displayCode",
        "implementationStatus": "native",
        "supported": true,
        "requiresPro": true,
        "displayProfileResolved": true
      }
    ]
  }
}
```

Mode ids are `deviceNative`, `managedSRGB`, `managedDisplayP3`, and `managedRec2020`. `requiresPro` is per-mode for forward compatibility even if a host currently gates all modes together.

### `display.setColorManagementMode`

Sets the host-global color-management mode and returns the selected display that actually changed.

```json
{
  "displayId": "69734272",
  "mode": "managedDisplayP3"
}
```

Sample response:

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "result": {
    "scope": "host",
    "selectedDisplayId": "69734272",
    "display": {
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
      "peakWhite": 3.0,
      "effectivePeakWhite": 2.0,
      "peakWhiteRange": { "minimum": 0.25, "maximum": 4.0 },
      "supportsPeakWhiteControl": true,
      "colorManagementMode": "managedDisplayP3",
      "supportedColorManagementModes": ["deviceNative", "managedSRGB", "managedDisplayP3", "managedRec2020"],
      "colorManagementImplementationStatus": "native",
      "colorManagementScope": "host",
      "displayProfileResolved": true
    }
  }
}
```

Unknown mode strings return JSON-RPC `invalidParams` (`-32602`). Known but unsupported modes return `colorManagementModeUnsupported` (`-32010`) with `requestedMode`, `supportedModes`, and `scope` in error data. If a host requires the write target to match selected output, mismatches return `displaySelectionMismatch` (`-32011`) with `requestedDisplayId`, `selectedDisplayId`, and `scope`.

## Notifications

### `connectionReady`

Sent after a successful WebSocket upgrade.

The server accepts one client at a time. A new successful WebSocket upgrade drops any existing client before `connectionReady` is sent to the new client.

### `pattern.changed`

Sent when the displayed pattern changes.

### `device.statusChanged`

Sent when device state changes.

### `display.changed`

Sent when display inventory, selected display, Peak White values, or color-management fields change. The payload has the same shape as a `display.list` result.

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
