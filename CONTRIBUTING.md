# Contributing

Thanks for helping improve PatternSpaceSDK.

## Development Setup

```bash
swift test
swift build
```

The package has no third-party dependencies. Please keep it that way unless the dependency materially improves safety or interoperability and is discussed first.

## Code Guidelines

- Keep public APIs small, typed, and documented in the README or protocol docs.
- Validate all network input before decoding or dispatch.
- Keep protocol parsing deterministic and bounded.
- Add or update tests for behavior changes.
- Prefer Swift Testing for new tests.
- Do not commit secrets, tokens, certificates, or generated build output.

## Pull Requests

Include:

- What changed
- Why it changed
- How it was tested
- Any compatibility impact for clients or servers

## Security

Do not file public issues for vulnerabilities. See [SECURITY.md](SECURITY.md).
