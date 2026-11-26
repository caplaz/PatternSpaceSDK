import Foundation
import Network
import Testing
@testable import PatternSpaceSDKServer
import PatternSpaceSDKCore

/// Regression: a rejected upgrade used to cancel the socket straight after
/// queueing the HTTP response, so clients saw the connection close with no
/// status and couldn't tell the user the pairing code was wrong.
@Suite(.serialized) struct UpgradeRejectionTests {
    @Test(arguments: [
        (18_814, nil as String?),
        (18_815, "Bearer 0000"),
    ])
    func missingOrWrongTokenGets401(port: Int, authorization: String?) async throws {
        let port = UInt16(port)
        let server = makeServer(token: "1234")
        let ready = readyStream(of: server)
        try server.start(port: port, deviceName: "PatternSpaceSDK rejection test")
        defer { server.stop() }
        var iterator = ready.makeAsyncIterator()
        #expect(await iterator.next() == true)

        var request = "GET /patternspace HTTP/1.1\r\n"
            + "Host: 127.0.0.1:\(port)\r\n"
            + "Upgrade: websocket\r\n"
            + "Connection: Upgrade\r\n"
            + "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
            + "Sec-WebSocket-Version: 13\r\n"
        if let authorization { request += "Authorization: \(authorization)\r\n" }
        request += "\r\n"

        let response = try await exchange(Data(request.utf8), port: port)
        #expect(response.hasPrefix("HTTP/1.1 401 Unauthorized"))
    }

    @Test func malformedUpgradeGets400() async throws {
        let port: UInt16 = 18_816
        let server = makeServer(token: "1234")
        let ready = readyStream(of: server)
        try server.start(port: port, deviceName: "PatternSpaceSDK bad request test")
        defer { server.stop() }
        var iterator = ready.makeAsyncIterator()
        #expect(await iterator.next() == true)

        let response = try await exchange(Data("GET / HTTP/1.1\r\nHost: x\r\n\r\n".utf8), port: port)
        #expect(response.hasPrefix("HTTP/1.1 400 Bad Request"))
    }

    // MARK: - Helpers

    private func makeServer(token: String?) -> PatternSpaceServer {
        PatternSpaceServer(token: token, delegate: MockDelegate()) { authenticated in
            ConnectionReadyParams(
                protocolVersion: PatternSpaceProtocolMetadata.protocolVersion,
                name: "Test PatternSpace",
                resolution: Resolution(width: 1920, height: 1080),
                colorFormat: "RGB",
                bitDepth: 10,
                hdrMode: "SDR",
                refreshRate: 60,
                outputRange: "full",
                currentPatternId: nil,
                sourceActive: true,
                authenticated: authenticated
            )
        }
    }

    private func readyStream(of server: PatternSpaceServer) -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        server.onListenerEvent = { event in
            if case .ready = event { continuation.yield(true) } else { continuation.yield(false) }
        }
        return stream
    }

    /// Sends `request` over a plain TCP socket and returns everything the
    /// server writes before it closes the connection.
    private func exchange(_ request: Data, port: UInt16) async throws -> String {
        let connection = NWConnection(
            host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        defer { connection.cancel() }
        let received = ResponseBuffer()

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    connection.stateUpdateHandler = { state in
                        if case .ready = state {
                            connection.send(content: request, completion: .contentProcessed { _ in })
                            Self.readUntilClosed(connection, into: received) { continuation.resume() }
                        }
                    }
                    connection.start(queue: .global())
                }
                return received.text
            }
            group.addTask {
                try await Task.sleep(for: .seconds(3))
                return received.text
            }
            defer { group.cancelAll() }
            return try await group.next() ?? ""
        }
    }

    private static func readUntilClosed(_ connection: NWConnection, into buffer: ResponseBuffer,
                                        done: @escaping @Sendable () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            if let data { buffer.append(data) }
            if isComplete || error != nil {
                done()
            } else {
                readUntilClosed(connection, into: buffer, done: done)
            }
        }
    }
}

private final class ResponseBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
