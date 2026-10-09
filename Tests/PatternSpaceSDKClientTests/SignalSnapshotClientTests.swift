import Foundation
import Network
import Testing
import PatternSpaceSDKCore
@testable import PatternSpaceSDKClient

@Suite(.serialized) struct SignalSnapshotClientTests {
    @Test(arguments: WebSocketTransportEpochTests.TransportPath.allCases)
    func bothTransportsReceiveSnapshotLargerThan64KiB(_ path: WebSocketTransportEpochTests.TransportPath) async throws {
        let response = SignalSnapshotResponse(evidence: .init(identity: .init(diagnosticsEpoch: "epoch", revision: 1),
            capture: .init(startedAt: 1, completedAt: 2), freshness: .current,
            appMapping: .init(status: .available, fields: [.init(name: "description", provenance: .appReported,
                text: String(repeating: "a", count: 100_000))])))
        let decoded = try await roundTrip(response, path: path)
        #expect(decoded == response)
    }

    @Test(arguments: WebSocketTransportEpochTests.TransportPath.allCases)
    func actualClientRejectsUnsupportedMajorSchema(_ path: WebSocketTransportEpochTests.TransportPath) async throws {
        let response = SignalSnapshotResponse(evidence: .init(schemaVersion: 2,
            identity: .init(diagnosticsEpoch: "epoch", revision: 1), capture: .init(startedAt: 1, completedAt: 2), freshness: .current))
        await #expect(throws: SignalSnapshotValidationError.unsupportedSchema(2)) {
            try await roundTrip(response, path: path)
        }
    }

    private func roundTrip(_ response: SignalSnapshotResponse, path: WebSocketTransportEpochTests.TransportPath) async throws -> SignalSnapshotResponse {
        let server = try await TestWebSocketServer.start()
        defer { server.stop() }
        let client = PatternSpaceClient(service: .init(name: "signal-test", endpoint: server.endpoint(path), port: server.port), token: nil)
        client.connect(); defer { client.disconnect() }
        let request = Task { try await client.device.signalSnapshot() }
        let deadline = ContinuousClock.now + .seconds(3)
        while server.requestIDs(on: 0).isEmpty {
            guard ContinuousClock.now < deadline else { throw EpochTestError.timedOut }
            try await Task.sleep(for: .milliseconds(10))
        }
        let id = try #require(server.requestIDs(on: 0).first)
        let result = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(response))
        let data = try JSONEncoder().encode(JSONValue.object(["jsonrpc": .string("2.0"), "id": .string(id), "result": result]))
        if response.evidence.schemaVersion == 1 {
            #expect(data.count > 65_536)
            #expect(data.count < SignalSnapshotResponse.maximumPayloadBytes)
        }
        server.send(String(decoding: data, as: UTF8.self), to: 0)
        return try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            Task { once.resume(with: await Result(catching: { try await request.value })) }
            Task {
                try? await Task.sleep(for: .seconds(3))
                once.resume(with: .failure(EpochTestError.timedOut))
            }
        }
    }
}
