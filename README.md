# PatternSpaceSDK

Swift SDK for controlling PatternSpace over its JSON WebSocket protocol.

PatternSpaceSDK gives calibration tools and automation clients a typed Swift interface for discovering PatternSpace devices, connecting over WebSocket, displaying patterns, querying device state, and receiving live status events.

## Features

- Swift Package Manager support
- No third-party dependencies
- Bonjour discovery via `_patternspace._tcp`
- JSON-RPC 2.0 request and notification envelopes
- WebSocket transport over Network.framework
- Optional bearer-token authentication
- Client API for pattern and device namespaces
- Server API for embedding the protocol in PatternSpace-compatible apps
- Swift Testing coverage for core JSON models, dispatch, input validation, WebSocket upgrade, and frame handling

## Requirements

- Swift 5.9+
- macOS 12+
- iOS 15+

## Installation

Add the package in Xcode:

```text
https://github.com/caplaz/PatternSpaceSDK.git
```

Or add it to a Swift package:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyTool",
    platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/caplaz/PatternSpaceSDK.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MyTool",
            dependencies: [
                .product(name: "PatternSpaceSDKClient", package: "PatternSpaceSDK")
            ]
        )
    ]
)
```

## Products

| Product | Purpose |
| --- | --- |
| `PatternSpaceSDKCore` | Shared JSON-RPC envelopes, pattern models, device schemas, color types, and events. |
| `PatternSpaceSDKClient` | Client-side discovery, connection, request/response handling, and typed namespaces. |
| `PatternSpaceSDKServer` | Server-side listener, WebSocket upgrade and framing, request dispatch, validation, and event broadcast. |

## Quick Start: Client

```swift
import PatternSpaceSDKClient
import PatternSpaceSDKCore

let services = await PatternSpaceDiscovery().discover(timeout: 3)
guard let service = services.first else {
    fatalError("No PatternSpace device found")
}

let client = PatternSpaceClient(service: service, token: "your-token")
client.connect()

Task {
    for await event in client.events {
        print("PatternSpace event:", event)
    }
}

try await client.pattern.displayColor(PSColor(r: 1, g: 0, b: 0), bitDepth: .ten)
try await client.pattern.clear()
client.disconnect()
```

## Quick Start: Server

```swift
import PatternSpaceSDKCore
import PatternSpaceSDKServer

final class Delegate: PatternSpaceServerDelegate {
    func displayPattern(id: String) async throws {
        print("Display pattern", id)
    }

    func displayColor(_ color: PSColor, bitDepth: BitDepth) async throws {
        print("Display color", color, bitDepth)
    }

    func displayRectangle(_ params: RectangleParams) async throws {
        print("Display rectangle", params)
    }

    func clearDisplay() async throws {
        print("Clear pattern")
    }

    func listPatterns(category: String?, subcategory: String?) async throws -> [PatternInfo] {
        []
    }

    func getPattern(id: String) async throws -> PatternInfo {
        throw PSDispatchError(.notFound)
    }

    func deviceInfo() async throws -> DeviceInfo {
        DeviceInfo(
            name: "PatternSpace",
            resolution: Resolution(width: 3840, height: 2160),
            colorFormat: "RGB",
            bitDepth: 10,
            hdrMode: "SDR",
            refreshRate: 60,
            outputRange: "full"
        )
    }

    func deviceStatus() async throws -> DeviceStatus {
        DeviceStatus(currentPatternId: nil, connectedClients: 0, sourceActive: true)
    }

    var isSourceActive: Bool { true }
    var currentResolution: Resolution { Resolution(width: 3840, height: 2160) }
}

let delegate = Delegate()
let server = PatternSpaceServer(
    token: "your-token",
    delegate: delegate,
    connectionReady: { authenticated, clientCount in
        ConnectionReadyParams(
            protocolVersion: "1.0",
            name: "PatternSpace",
            resolution: Resolution(width: 3840, height: 2160),
            colorFormat: "RGB",
            bitDepth: 10,
            hdrMode: "SDR",
            refreshRate: 60,
            outputRange: "full",
            currentPatternId: nil,
            connectedClients: clientCount,
            sourceActive: true,
            authenticated: authenticated,
        )
    }
)

try server.start(port: 7878, deviceName: "PatternSpace")
```

## Authentication

When a server is configured with a token, clients must send:

```http
Authorization: Bearer <token>
```

The server rejects unauthorized upgrade requests with HTTP `401 Unauthorized` before accepting the WebSocket. Token comparison is constant-time. Prefer a high-entropy per-device token stored in the platform keychain or another secure credential store.

## Protocol

The SDK uses JSON-RPC 2.0 envelopes over WebSocket at:

```text
ws://<host>:7878/patternspace
```

Supported method namespaces:

Patch color methods:

- `pattern.displayColor`
- `pattern.displayRectangle`
- `pattern.clear`

Existing pattern list methods:

- `pattern.list`
- `pattern.display`
- `pattern.get`

Device methods:

- `device.info`
- `device.status`

Notifications:

- `connectionReady`
- `pattern.changed`
- `device.statusChanged`

See [Documentation](Documentation/Protocol.md) for the wire-format overview.

## Development

```bash
swift test
swift build
```

The package intentionally avoids third-party dependencies so it can be embedded in calibration tools and app targets with minimal supply-chain surface.

## Versioning

PatternSpaceSDK follows semantic versioning. The initial `0.x` series may still adjust public API while the JSON protocol stabilizes.

## License

PatternSpaceSDK is available under the Apache License 2.0. See [LICENSE](LICENSE).
