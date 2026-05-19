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
    "color": { "r": 1.0, "g": 0.0, "b": 0.0 },
    "bitDepth": 10
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

### `pattern.displayColor`

Displays a full-screen RGB color.

```json
{
  "color": { "r": 1.0, "g": 1.0, "b": 1.0 },
  "bitDepth": 10
}
```

Color channels are normalized `0.0...1.0`.

### `pattern.displayRectangle`

Displays a foreground rectangle over a background color.

```json
{
  "foreground": { "r": 1.0, "g": 1.0, "b": 1.0 },
  "background": { "r": 0.0, "g": 0.0, "b": 0.0 },
  "x": 960,
  "y": 540,
  "width": 1920,
  "height": 1080,
  "bitDepth": 10
}
```

Rectangle coordinates are integer pixel coordinates in the current display space.

### `pattern.clear`

Clears the active remote pattern.

```json
{}
```

### `pattern.list`

Lists available patterns, optionally filtered by category and subcategory.

```json
{
  "category": "color",
  "subcategory": "primary"
}
```

### `pattern.display`

Displays a named pattern by id.

```json
{
  "id": "color/red",
  "params": {}
}
```

### `pattern.get`

Gets metadata for one pattern.

```json
{
  "id": "color/red"
}
```

### `device.info`

Returns static device information such as name, resolution, color format, bit depth, HDR mode, refresh rate, and output range.

### `device.status`

Returns current status, including active pattern id, connected client count, and whether the JSON source is active.

## Notifications

### `connectionReady`

Sent after a successful WebSocket upgrade.

### `pattern.changed`

Sent when the displayed pattern changes.

### `device.statusChanged`

Sent when device state changes.

## Limits

- Maximum HTTP upgrade header size: 16 KiB
- Maximum WebSocket payload size: 65,536 bytes
- Client frames must be masked
- Fragmented frames are not accepted in the initial implementation
