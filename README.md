# PatternSpaceSDK

WebSocket JSON-RPC SDK for PatternSpace integration.

PatternSpaceSDK gives calibration tools and automation clients a typed Swift interface for discovering PatternSpace devices, connecting over WebSocket, displaying patterns, querying capabilities, inspecting richer device/display state, adjusting Peak White and color-management modes, and receiving live status events.

## Features

- Swift Package Manager support
- No third-party dependencies
- Bonjour discovery via `_patternspace._tcp`
- JSON-RPC 2.0 request and notification envelopes
- WebSocket transport over Network.framework
- Optional bearer-token authentication
- Client API for capabilities, pattern, device, and display namespaces
- Server API for embedding the protocol in PatternSpace-compatible apps
- Swift Testing coverage for core JSON models, dispatch, input validation, WebSocket upgrade, and frame handling

## Requirements

- Swift 5.9+
- macOS 12+
- iOS 15+
- PatternSpace JSON protocol `1.1`

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
        .package(url: "https://github.com/caplaz/PatternSpaceSDK.git", from: "0.4.0")
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

try await client.pattern.displayColor(PSColor(r: 1, g: 0, b: 0), bitDepth: .ten, size: 10)
let capabilities = try await client.capabilities.list()
print(capabilities.namespaces)

try await client.pattern.displayPatch(
    background: PSColor(r: 0, g: 0, b: 0),
    rectangles: [
        PatchRectangle(color: PSColor(r: 1, g: 1, b: 1), x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    ],
    bitDepth: .ten
)
let displays = try await client.display.list()
if let selected = displays.displays.first(where: \.selected) {
    _ = try await client.display.setPeakWhite(displayId: selected.id, peakWhite: 3.0)
    let modes = try await client.display.listColorManagementModes(displayId: selected.id)
    if modes.modes.contains(where: { $0.id == .managedDisplayP3 && $0.supported }) {
        _ = try await client.display.setColorManagementMode(displayId: selected.id, mode: .managedDisplayP3)
    }
}
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

    func displayPatch(_ params: PatchParams) async throws {
        print("Display patch", params)
    }

    func clearDisplay() async throws {
        print("Clear pattern")
    }

    func listPatterns(category: String?, subcategory: String?) async throws -> [PatternInfo] {
        []
    }

    func getPattern(id: String) async throws -> PatternInfo {
        throw PSDispatchError(.patternNotFound)
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
        DeviceStatus(
            currentPatternId: nil,
            sourceActive: true,
            selectedSource: "PatternSpace JSON",
            selectedDisplayId: "main",
            colorManagementMode: .deviceNative,
            colorManagementImplementationStatus: .native,
            displayProfileResolved: true,
            colorManagementScope: .host,
            authRequired: true,
            connectedClientCount: 1,
            appVersion: "1.1.0",
            buildNumber: "1",
            sdkVersion: PatternSpaceProtocolMetadata.sdkVersion,
            protocolVersion: PatternSpaceProtocolMetadata.protocolVersion
        )
    }

    func capabilities() async throws -> CapabilitiesResult {
        CapabilitiesResult(
            protocolVersion: PatternSpaceProtocolMetadata.protocolVersion,
            app: AppMetadata(name: "PatternSpace", version: "1.1.0", build: "1"),
            sdkVersion: PatternSpaceProtocolMetadata.sdkVersion,
            platform: .macOS,
            authRequired: true,
            namespaces: JSONRPCDispatcher.routeManifest,
            features: CapabilityFeatures(
                events: true,
                displayInventory: true,
                peakWhiteControl: true,
                colorManagementModes: true,
                measurementRange: false,
                catalogPatterns: true,
                customICCBuilder: false,
                httpBridge: false
            )
        )
    }

    func listDisplays() async throws -> DisplayListResult {
        DisplayListResult(
            platform: .macOS,
            selectedDisplayId: "main",
            displays: [
                DisplayEntry(
                    id: "main",
                    name: "Main Display",
                    selected: true,
                    connection: .builtIn,
                    resolution: Resolution(width: 3840, height: 2160),
                    refreshRate: 60,
                    colorSpaceName: "Display P3",
                    cgColorSpaceName: "kCGColorSpaceDisplayP3",
                    maximumPotentialEDR: 4.0,
                    maximumCurrentEDR: 2.0,
                    peakWhite: 2.0,
                    effectivePeakWhite: 2.0,
                    peakWhiteRange: PeakWhiteRange(maximum: 4.0),
                    supportsPeakWhiteControl: true,
                    colorManagementMode: .deviceNative,
                    supportedColorManagementModes: ColorManagementMode.allCases,
                    colorManagementImplementationStatus: .native,
                    colorManagementScope: .host,
                    displayProfileResolved: true
                )
            ]
        )
    }

    func setPeakWhite(_ params: SetPeakWhiteParams) async throws -> DisplayEntry {
        guard params.displayId == "main" else {
            throw PSDispatchError(.displayNotFound, data: .object(["displayId": .string(params.displayId)]))
        }
        guard params.peakWhite >= PeakWhiteRange.absoluteMinimum, params.peakWhite <= 4.0 else {
            throw PSDispatchError(
                .peakWhiteOutOfRange,
                data: .object([
                    "displayId": .string(params.displayId),
                    "peakWhite": .double(params.peakWhite),
                    "minimum": .double(PeakWhiteRange.absoluteMinimum),
                    "maximum": .double(4.0)
                ])
            )
        }
        return DisplayEntry(
            id: "main",
            name: "Main Display",
            selected: true,
            connection: .builtIn,
            resolution: Resolution(width: 3840, height: 2160),
            refreshRate: 60,
            colorSpaceName: "Display P3",
            cgColorSpaceName: "kCGColorSpaceDisplayP3",
            maximumPotentialEDR: 4.0,
            maximumCurrentEDR: 2.0,
            peakWhite: params.peakWhite,
            effectivePeakWhite: min(params.peakWhite, 2.0),
            peakWhiteRange: PeakWhiteRange(maximum: 4.0),
            supportsPeakWhiteControl: true,
            colorManagementMode: .deviceNative,
            supportedColorManagementModes: ColorManagementMode.allCases,
            colorManagementImplementationStatus: .native,
            colorManagementScope: .host,
            displayProfileResolved: true
        )
    }

    func listColorManagementModes(displayId: String) async throws -> ColorManagementModeList {
        guard displayId == "main" else {
            throw PSDispatchError(.displayNotFound, data: .object(["displayId": .string(displayId)]))
        }
        return ColorManagementModeList(
            displayId: displayId,
            selectedMode: .deviceNative,
            scope: .host,
            modes: [
                ColorManagementModeEntry(
                    id: .deviceNative,
                    label: "Device Native",
                    layerColorSpace: "displayProfile",
                    inputEncoding: .displayCode,
                    implementationStatus: .native,
                    supported: true,
                    requiresPro: true,
                    displayProfileResolved: true
                ),
                ColorManagementModeEntry(
                    id: .managedDisplayP3,
                    label: "Managed Display P3",
                    layerColorSpace: "displayP3",
                    inputEncoding: .linearLight,
                    implementationStatus: .native,
                    supported: true,
                    requiresPro: true,
                    displayProfileResolved: nil
                )
            ]
        )
    }

    func setColorManagementMode(_ params: SetColorManagementModeParams) async throws -> SetColorManagementModeResult {
        guard params.displayId == "main" else {
            throw PSDispatchError(.displayNotFound, data: .object(["displayId": .string(params.displayId)]))
        }
        let display = DisplayEntry(
            id: "main",
            name: "Main Display",
            selected: true,
            connection: .builtIn,
            resolution: Resolution(width: 3840, height: 2160),
            refreshRate: 60,
            colorSpaceName: "Display P3",
            cgColorSpaceName: "kCGColorSpaceDisplayP3",
            maximumPotentialEDR: 4.0,
            maximumCurrentEDR: 2.0,
            peakWhite: 2.0,
            effectivePeakWhite: 2.0,
            peakWhiteRange: PeakWhiteRange(maximum: 4.0),
            supportsPeakWhiteControl: true,
            colorManagementMode: params.mode,
            supportedColorManagementModes: ColorManagementMode.allCases,
            colorManagementImplementationStatus: .native,
            colorManagementScope: .host,
            displayProfileResolved: true
        )
        return SetColorManagementModeResult(scope: .host, selectedDisplayId: params.displayId, display: display)
    }

    var isSourceActive: Bool { true }
}

let delegate = Delegate()
let server = PatternSpaceServer(
    token: "your-token",
    delegate: delegate,
    connectionReady: { authenticated in
        ConnectionReadyParams(
            protocolVersion: PatternSpaceProtocolMetadata.protocolVersion,
            name: "PatternSpace",
            resolution: Resolution(width: 3840, height: 2160),
            colorFormat: "RGB",
            bitDepth: 10,
            hdrMode: "SDR",
            refreshRate: 60,
            outputRange: "full",
            currentPatternId: nil,
            sourceActive: true,
            authenticated: authenticated,
        )
    }
)

try server.start(port: 7878, deviceName: "PatternSpace")
```

`PatternSpaceServer` is single-client by design. When a new WebSocket upgrade succeeds, the server drops any existing client before sending `connectionReady` to the new one.

## Authentication

When a server is configured with a token, clients must send:

```http
Authorization: Bearer <token>
```

The server rejects unauthorized upgrade requests with HTTP `401 Unauthorized` before accepting the WebSocket. Token comparison is constant-time. Prefer a high-entropy per-device token stored in the platform keychain or another secure credential store.

Pass `nil` for the server token to run in insecure mode. Insecure mode should be limited to trusted local networks or test harnesses.

## Protocol

The SDK uses JSON-RPC 2.0 envelopes over WebSocket at:

```text
ws://<host>:7878/patternspace
```

Supported method namespaces:

Patch color methods:

- `pattern.displayColor`
- `pattern.displayPatch`
- `pattern.clear`

Existing pattern list methods:

- `pattern.list`
- `pattern.display`
- `pattern.get`

Capabilities methods:

- `capabilities.list`

Device methods:

- `device.info`
- `device.status`

Display methods:

- `display.list`
- `display.setPeakWhite`
- `display.listColorManagementModes`
- `display.setColorManagementMode`

Notifications:

- `connectionReady`
- `pattern.changed`
- `device.statusChanged`
- `display.changed`

See [Documentation](Documentation/Protocol.md) for the wire-format overview.

The `sourceActive` field is a race-condition guard. In normal PatternSpace operation, changing away from the JSON source stops the server and closes the socket rather than keeping a client connected with `sourceActive: false`.

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
