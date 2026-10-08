# Signal transparency (SDK 1.1.0)

These optional additions retain PatternSpace JSON protocol 1.3. Evidence has its own schema version, currently 1. No new listener, credential, dependency or physical output behavior is introduced.

## Discovery and compatibility

`CapabilityFeatures.signalSnapshot` and `signalProbe` are optional Boolean fields with nil defaults. Older hosts omit them. Clients enable a feature only when its flag is true and handle method-not-found safely. The dispatcher filters the two unsupported methods from the host-supplied namespace manifest and removes their flags. Every existing namespace entry stays unchanged. `JSONRPCDispatcher.routeManifest` is the complete SDK surface, including optional methods.

Existing server conformers need no additions: `supportsSignalSnapshot` and `supportsSignalProbe` default to false, and the associated methods default to throwing `methodNotFound`. Opt-in hosts implement the flag, method and advertised capability together. No cases are added to existing public enums.

## `device.signalSnapshot`

Accepts absent parameters, `{}` or `[]`. Nonempty or scalar parameters, including null, return `invalidParams`. The authenticated connection identity is supplied by the server, never accepted from JSON. Reading does not require the JSON source to be active and must not admit output or change ownership.

The delegate is:

```swift
func signalSnapshot(context: OutputRequestContext) async throws -> SignalSnapshotResponse
```

The result is a response envelope:

```json
{
  "evidence": {
    "schemaVersion": 1,
    "identity": {
      "diagnosticsEpoch": "export-local-epoch",
      "revision": 7,
      "targetRevision": 2,
      "configurationRevision": 4,
      "ownershipRevision": 3
    },
    "capture": { "startedAt": 1791450000, "completedAt": 1791450000.2 },
    "freshness": "current",
    "source": { "status": "unknown", "fields": [], "samples": [], "totalSampleCount": 0, "omittedSampleCount": 0 },
    "appMapping": { "status": "unknown", "fields": [], "samples": [], "totalSampleCount": 0, "omittedSampleCount": 0 },
    "sdiFrame": { "status": "notApplicable", "fields": [], "samples": [], "totalSampleCount": 0, "omittedSampleCount": 0 },
    "physicalSignal": { "status": "unknown", "fields": [], "samples": [], "totalSampleCount": 0, "omittedSampleCount": 0 },
    "omissions": []
  }
}
```

Optional `probeAuthorization` is omitted from this evidence-only example. It contains `expectedContextGuard` and `context`, where context declares the diagnostics epoch, optional target lifetime, target revision, configuration revision and ownership revision. A diagnostics revision or new same-owner patch does not change this context. Never export the response envelope or authorization.

## Evidence fields

- `identity` separates latest accepted content from currently published/coalesced content using optional `acceptedContentID` / `acceptedSequence` and `publishedContentID` / `publishedSequence`. It also carries optional `sourceLifetime` and `targetLifetime`. Revision is ordered only within one diagnostics epoch, minted independently of JSON server startup.
- `capture` is an interval in Unix seconds. `freshness` uses `current`, `historical` or `collecting`. Profile/headroom field observations may carry their own intervals; no atomic OS-settings observation is implied.
- Four stages are `source`, `appMapping`, `sdiFrame`, and `physicalSignal`. A stage declares `status`, optional `provenance` and `reason`, typed `fields`, typed `samples`, total sample count and omitted sample count.
- A stage may carry the actual `contentID`, `configurationIdentity`, `mappingIdentity`, `presentationIdentity`, `targetLifetime`, monotonic `drawSequence`, `submittedAt`, `presentedAt`, and separate capture interval. Selected configuration and an older confirmed presentation must remain separately identifiable. Callback time is an app observation, not a measured panel response time.
- `SignalFieldEvidence` uses machine-key `name`, `provenance`, optional `number`, `integer`, `token`, `flag` or `text`, optional `units`, `reason`, and `capture`. Field names, units and tokens are not localized labels. Hosts must declare concrete stage semantics and avoid interpreting one stage's numbers as another stage's physical codes.
- `SignalSampleEvidence` identifies background/rectangle `role` and zero-based `ordinal`. It separates `receivedIntegers` from `receivedValues`, `effectiveRendererInput` and `calculatedCodes`, with optional representation, declared bit depth, geometry, fields and reason. Component structs use `first`, `second`, `third`; containing observations declare RGB versus Y/Cb/Cr and units/layout. Received codes must come from ingress, not a reconstruction of normalized values. Library pattern identifiers/parameters and blank state belong in explicit fields rather than invented RGB samples.

Provenance includes received, calculated, appReported, packed, unknown and notApplicable. Reasons include nonFinite, superseded, readerBusy, timedOut, rectangleLimit and payloadLimit. Physical HDMI link depth, cable codes, dithering and receiver behavior remain unknown without external capture. SDI packed-byte evidence establishes software encoding only. There is no bit-perfect certification.

`SignalToken` is an open Codable raw string. Unknown tokens are preserved on round trip and must be displayed as unknown/unavailable, never mapped to a recognized success. Unknown additive object fields are ignored. `decodeValidated` and client reads reject an unsupported major schema with `SignalSnapshotValidationError.unsupportedSchema(version)` before decoding stage fields or authorization. `validatedData` likewise rejects unsupported schemas. The `isSupportedSchema` convenience remains available for locally constructed evidence; it is not a substitute for validated wire decoding. Existing device-info bit depth keeps its prior meaning and cannot substitute for physical signal evidence.

## Bounds and encoding

Every stage retains at most 64 sample records, in order, with `totalSampleCount` and `omittedSampleCount`. The initializer bounds records; validated decoding rejects oversized or inconsistent wire counts. Missing records are explicitly omitted and must not appear silently absent. No frame buffer field exists.

`SignalSnapshotResponse.validatedData()` verifies schema version, finite numbers and authorization consistency, then encodes sorted-key UTF-8 JSON. It caps the payload at 256 KiB. If optional stage fields/samples exceed the bound, it removes those details, preserves immutable identities/counts, adds top-level `payloadLimit`, and marks affected stages with that omission reason. If the retained identity/envelope still exceeds the limit, encoding throws. The dispatcher also checks the complete JSON-RPC success response bound. `decodeValidated` checks bytes and the schema header before decoding and validates finite fields/counts afterward. Both client transports accept complete incoming SDK messages up to 256 KiB, including the JSON-RPC envelope; server incoming request limits are unchanged. Malformed or oversized host evidence becomes an error, not plausible truncated evidence.

Nonfinite optional scalar/sample inputs become unavailable with `nonFinite`. Mandatory capture intervals retain their original timestamp inputs; NaN/infinity or reversed intervals fail validation as `invalidEvidence` rather than inventing an observation time. Other invalid geometry values fail validated encoding. Consumers should use validated envelope APIs instead of directly decoding untrusted evidence. The SDK does not perform user export redaction: hosts must replace potentially identifying lifetimes/IDs with export-local opaque IDs and remove sensitive names, paths, IPs, serials and sessions from optional descriptions. Share `evidence` only, using a frozen redacted copy.

## `pattern.displayProbe`

Parameters are the flat `PatchParams` shape plus `expectedContextGuard`:

```json
{
  "background": { "r": 0, "g": 0, "b": 0 },
  "rectangles": [
    { "color": { "r": 1, "g": 0, "b": 0 }, "x": 0, "y": 0, "width": 1, "height": 1 }
  ],
  "bitDepth": 10,
  "expectedContextGuard": "opaque-connection-context-token"
}
```

Swift wraps these in `SignalProbeParams(patch:expectedContextGuard:)`. The guard must contain 1–512 bytes of printable non-whitespace ASCII; contents are opaque and have no SDK semantics. Missing, wrong-type, empty, oversized or malformed guards return `invalidParams`. Patch color, geometry, count and bit depth pass the exact shared ordinary patch parser. Unsupported probes return method-not-found even while the JSON source is inactive; supported probes require an active source.

The delegate is:

```swift
func displayProbe(_ params: SignalProbeParams, context: OutputRequestContext) async throws
```

Hosts must compare the authenticated connection, guard and current expected context synchronously on the admission actor immediately before existing output admission, with no suspension between check and commit. The dispatcher cannot validate app-owned context. Stale target/configuration/ownership context throws `displayError`; a guard bound to a different connection throws `notAuthorized`; inactive source throws `sourceNotActive`. Rejected probes must not mutate output, advance ownership or consume render allowance. Never implement unsupported or stale probes using unguarded `displayPatch` fallback.

Issue one stable guard for the eligible authenticated connection and exact context. Refresh, newer diagnostics revisions, same-owner patches, reader timeout and cancelled reads must not rotate it. Real context/eligibility transitions or connection/service replacement retire it. Changes A→B→A must not revive old guards. Capture evidence first, reconcile eligibility/context during response assembly, and omit authorization from historical, superseded or old-connection results. A current partial timeout may retain authorization only when readiness and eligibility are independently established. Validated envelopes reject authorization whose context differs from evidence identity or whose evidence is not current.

The client API sends one explicit sample:

```swift
let response = try await client.device.signalSnapshot()
if response.evidence.isSupportedSchema,
   let authorization = response.probeAuthorization {
    try await client.pattern.displayProbe(
        SignalProbeParams(patch: sample, expectedContextGuard: authorization.expectedContextGuard)
    )
}
```

Display success remains ordinary admission, not physical presentation. Submitted SDI work follows the host's existing confirmation contract. SDK methods add no timeout, retry, automatic replay or transport teardown. Cancel cannot recall dispatched/admitted samples. Apps may settle a local UI deadline as outcome unknown while retaining the SDK continuation and serial output queue slot until the real response or disconnect; they must not free that slot, replace the worker or claim the sample was cancelled. Existing output blank/resume and composer ordering stays unchanged.
