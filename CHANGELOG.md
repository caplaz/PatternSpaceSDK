# Changelog

All notable changes to PatternSpaceSDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows semantic versioning.

## [0.1.0] - 2026-05-18

### Added

- Initial Swift Package Manager package.
- `PatternSpaceSDKCore` product with JSON-RPC envelopes, JSON values, error codes, pattern models, device schemas, and events.
- `PatternSpaceSDKClient` product with Bonjour discovery, WebSocket transport, request correlation, reconnection, and typed pattern/device namespaces.
- `PatternSpaceSDKServer` product with TCP listener, WebSocket upgrade handling, manual frame codec, JSON-RPC dispatch, input validation, auth rejection, rate limiting, and event broadcast.
- Swift Testing coverage for core models, validation, dispatch, WebSocket upgrade, and WebSocket frames.
