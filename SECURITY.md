# Security Policy

PatternSpaceSDK handles local-network control messages for display calibration workflows. Treat all network input as untrusted.

## Supported Versions

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |

## Reporting a Vulnerability

Please report suspected vulnerabilities privately to the maintainers rather than opening a public issue. Include:

- Affected version or commit
- Reproduction steps
- Expected and actual behavior
- Any proof-of-concept payloads

## Security Design Notes

- Servers may require bearer-token authentication during the WebSocket upgrade.
- Unauthorized upgrade requests are rejected with HTTP `401 Unauthorized`.
- Token comparison is constant-time.
- WebSocket client frames must be masked.
- Frame payload size is bounded.
- HTTP upgrade headers are bounded.
- JSON-RPC methods are explicitly allow-listed by the dispatcher.

Use high-entropy per-device tokens and store them in a platform credential store such as Keychain.
