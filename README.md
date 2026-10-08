# PatternSpaceSDK

WebSocket JSON-RPC SDK for PatternSpace integration.

PatternSpaceSDK gives calibration tools and automation clients a typed Swift interface for discovering PatternSpace devices, connecting over WebSocket, displaying patterns, querying capabilities, inspecting richer device/display state, adjusting Peak White, discovering output color presets, blanking and resuming output, and receiving live status events.

## Features

- Swift Package Manager support
- No third-party dependencies
- Bonjour discovery via `_patternspace._tcp`
- JSON-RPC 2.0 request and notification envelopes
- WebSocket transport over Network.framework
- Optional bearer-token authentication
- Client API for capabilities, pattern, device, display, and output namespaces
- Server API for embedding the protocol in PatternSpace-compatible apps
- Swift Testing coverage for core JSON models, dispatch, input validation, WebSocket upgrade, and frame handling

## Requirements

- Swift 5.9+
- macOS 12+
- iOS 15+
- PatternSpace JSON protocol `1.3`

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
        .package(url: "https://github.com/caplaz/PatternSpaceSDK.git", from: "1.1.0")
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
    let presets = try await client.display.listOutputColorPresets(displayId: selected.id)
    if let hdr = presets.presets.first(where: { $0.id == .hdrBT2020PQ }) {
        let config = try await client.display.getOutputColorPreset(displayId: selected.id, presetId: hdr.id)
        if config.preset.supported {
            _ = try await client.display.setOutputColorPreset(displayId: selected.id, presetId: hdr.id)
        }
    }
    _ = try await client.display.setMeasurementRange(
        displayId: selected.id,
        measurementRange: .legal
    )
}
if capabilities.outputBlank == true {
    let blanked = try await client.output.blank()
    print("Blanked:", blanked.blanked as Any, "revision", blanked.revision)
    _ = try await client.output.resume()
}
try await client.pattern.clear()
client.disconnect()
```

## Quick Start: Server

```swift
import PatternSpaceSDKCore
import PatternSpaceSDKServer

final class Delegate: PatternSpaceServerDelegate {
    // Output writes carry the server-minted identity of the sending client.
    // Compare `context.clientID` with the client reported by
    // `onClientConnected` before mutating output.
    func displayPattern(id: String, context: OutputRequestContext) async throws {
        print("Display pattern", id, "from", context.clientID)
    }

    func displayColor(_ color: PSColor, bitDepth: BitDepth,
                      context: OutputRequestContext) async throws {
        print("Display color", color, bitDepth)
    }

    func displayPatch(_ params: PatchParams, context: OutputRequestContext) async throws {
        print("Display patch", params)
    }

    func clearDisplay(context: OutputRequestContext) async throws {
        print("Clear pattern")
    }

    // Hosts without blank support must throw methodNotFound here and leave
    // `CapabilitiesResult.outputBlank` nil.
    func blankOutput(context: OutputRequestContext) async throws -> OutputStatus {
        throw PSDispatchError(.methodNotFound)
    }

    func resumeOutput(context: OutputRequestContext) async throws -> OutputStatus {
        throw PSDispatchError(.methodNotFound)
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
            displayProfileResolved: true,
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
                outputColorPresets: true,
                measurementRange: true,
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
                    supportsPeakWhiteControl: false,
                    displayProfileResolved: true,
                outputColorPresetId: .deviceNative,
                selectedMeasurementRange: .full,
                supportedOutputColorPresetIds: [.deviceNative, .sdrReferenceSRGB, .hdrP3D65PQ, .extLinearSRGBHDR],
                    outputColorPresetImplementationStatus: "native"
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
            supportsPeakWhiteControl: false,
            displayProfileResolved: true,
            outputColorPresetId: .deviceNative,
            supportedOutputColorPresetIds: [.deviceNative, .sdrReferenceSRGB, .hdrP3D65PQ, .extLinearSRGBHDR],
            outputColorPresetImplementationStatus: "native"
        )
    }

    func listOutputColorPresets(displayId: String) async throws -> OutputColorPresetList {
        guard displayId == "main" else {
            throw PSDispatchError(.displayNotFound, data: .object(["displayId": .string(displayId)]))
        }
        return OutputColorPresetList(
            displayId: displayId,
            selectedPresetId: .deviceNative,
            scope: .host,
            catalogRevision: "2026-06-17.1",
            presets: [
                OutputColorPresetSummary(
                    id: .deviceNative,
                    label: "Device Native",
                    group: "device",
                    family: .device,
                    supported: true,
                    requiresPro: false,
                    implementationStatus: .native
                ),
                OutputColorPresetSummary(
                    id: .extLinearSRGBHDR,
                    label: "Extended Linear sRGB HDR",
                    group: "linearHDR",
                    family: .linearHDR,
                    supported: true,
                    requiresPro: true,
                    implementationStatus: .native
                )
            ]
        )
    }

    func getOutputColorPreset(_ params: GetOutputColorPresetParams) async throws -> GetOutputColorPresetResult {
        guard params.displayId == "main" else {
            throw PSDispatchError(.displayNotFound, data: .object(["displayId": .string(params.displayId)]))
        }
        return GetOutputColorPresetResult(
            displayId: params.displayId,
            catalogRevision: "2026-06-17.1",
            preset: OutputColorPresetConfig(
                id: params.presetId,
                label: "Device Native",
                group: "device",
                family: .device,
                gamut: .displayNative,
                whitePoint: .displayNative,
                transfer: .displayNative,
                dynamicRange: .sdr,
                toneMapping: .none,
                inputEncoding: .displayCode,
                implementationStatus: .native,
                supported: true,
                requiresPro: false
            )
        )
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

server.onClientConnected = { clientID in
    Task { @MainActor in print("Client connected", clientID) }
}
server.onClientDisconnected = { clientID, reason in
    Task { @MainActor in print("Client disconnected", clientID, reason) }
}

try server.start(port: 7878, deviceName: "PatternSpace")
```

`PatternSpaceServer` is single-client by design. When a new WebSocket upgrade succeeds, the server drops any existing client before sending `connectionReady` to the new one.

Every authenticated client receives exactly one `onClientConnected` and one `onClientDisconnected` callback. On replacement, the old client's `.evicted` callback is delivered before the new client's `onClientConnected`; `stop()` reports `.serverStopped` for clients still connected. Callbacks are serialized on an internal queue and may run on the thread that calls `stop()`, so keep them short, hop to your own actor or queue, and never call `DispatchQueue.main.sync` from one.

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

`/patternspace` is the canonical path. The server also accepts upgrades on any
path (for example `/`), because `NWProtocolWebSocket` clients connecting through
a hostPort or Bonjour service endpoint cannot attach a path. Authentication is
enforced by the bearer token, not the path.

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
- `display.listOutputColorPresets`
- `display.getOutputColorPreset`
- `display.setOutputColorPreset`
- `display.setMeasurementRange`

Output methods (check `capabilities.list` → `outputBlank` first):

- `output.blank`
- `output.resume`

Notifications:

- `connectionReady`
- `pattern.changed`
- `device.statusChanged`
- `display.changed`

See [Documentation](Documentation/Protocol.md) for the wire-format overview.

The `sourceActive` field is a race-condition guard. In normal PatternSpace operation, changing away from the JSON source stops the server and closes the socket rather than keeping a client connected with `sourceActive: false`.

## Signal transparency (SDK 1.1.0)

Check `capabilities.features.signalSnapshot == true` before reading `client.device.signalSnapshot()`. The response separates immutable `evidence` from optional connection-bound `probeAuthorization`. Share or export evidence only. Schema 1 records source request provenance, app mapping, SDI software encoding and physical-signal unknowns; software observations do not certify a physical cable or panel.

A host opts in with `supportsSignalSnapshot` / `supportsSignalProbe` and implements `signalSnapshot(context:)` / `displayProbe(_:context:)`. Existing delegates compile unchanged: new hooks default to unsupported and new capability fields default to nil. Unsupported hosts omit the new namespace methods and feature flags and return method-not-found. Advertise each flag only for supported functionality; `JSONRPCDispatcher.routeManifest` includes optional routes and dispatch filters them for the host.

When `features.signalProbe == true` and the snapshot provides authorization, an explicit sample uses `client.pattern.displayProbe(SignalProbeParams(patch: patch, expectedContextGuard: authorization.expectedContextGuard))`. The host must validate the authenticated connection and exact expected context atomically with its existing patch admission. The SDK shares ordinary patch validation but never substitutes an unguarded patch write. A success follows the existing admission contract; cancelling a submitted request cannot prevent a sample from appearing. The SDK adds no RPC timeout, automatic retry, or transport changes.

See [Signal transparency](Documentation/SignalTransparency.md) for the schema, bounds, forward compatibility and host obligations. JSON protocol remains 1.3; the evidence schema is independently versioned.

## Development

```bash
swift test
swift build
```

The package intentionally avoids third-party dependencies so it can be embedded in calibration tools and app targets with minimal supply-chain surface.

## Versioning

PatternSpaceSDK follows semantic versioning. Starting with `1.0.0`, source-breaking public API changes are reserved for major releases. See [CHANGELOG.md](CHANGELOG.md) for migration notes, including the `1.0.0` context-bearing delegate and client-lifecycle changes.

## License

PatternSpaceSDK is available under the Apache License 2.0. See [LICENSE](LICENSE).
