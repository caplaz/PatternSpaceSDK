# PatternSpace JSON Protocol

PatternSpaceSDK speaks a JSON-RPC 2.0 subset over WebSocket.

```text
ws://<host>:7878/patternspace
```

Bonjour service type:

```text
_patternspace._tcp
```

The server advertises `protocolVersion=1.0` in the TXT record.

## Authentication

If the server is configured with a token, the HTTP upgrade request must include:

```http
Authorization: Bearer <token>
```

Invalid or missing credentials receive HTTP `401 Unauthorized`; valid clients receive `101 Switching Protocols`.

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

### `device.status`

Returns current status, including active pattern id and whether the JSON source is active.

## Notifications

### `connectionReady`

Sent after a successful WebSocket upgrade.

The server accepts one client at a time. A new successful WebSocket upgrade drops any existing client before `connectionReady` is sent to the new client.

### `pattern.changed`

Sent when the displayed pattern changes.

### `device.statusChanged`

Sent when device state changes.

## Limits

- Maximum HTTP upgrade header size: 16 KiB
- Maximum WebSocket payload size: 65,536 bytes
- Client frames must be masked
- Fragmented frames are not accepted in the initial implementation
