import Foundation
import Testing
@testable import PatternSpaceSDKServer

private let validRequest = """
GET /patternspace HTTP/1.1\r
Host: localhost:7878\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
Sec-WebSocket-Version: 13\r
Authorization: Bearer test-token\r
\r

"""

private let unauthRequest = """
GET /patternspace HTTP/1.1\r
Host: localhost:7878\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
Sec-WebSocket-Version: 13\r
\r

"""

@Suite struct WebSocketUpgradeHandlerTests {
    @Test func acceptsValidRequest() {
        let handler = WebSocketUpgradeHandler(token: "test-token")
        let result = handler.handle(requestData: Data(validRequest.utf8))
        guard case .accept(let data) = result else {
            Issue.record("Expected accept")
            return
        }
        let response = String(data: data, encoding: .utf8) ?? ""
        #expect(response.hasPrefix("HTTP/1.1 101"))
        #expect(response.contains("Sec-WebSocket-Accept:"))
    }

    @Test func acceptKeyIsCorrectForWellKnownInput() {
        let handler = WebSocketUpgradeHandler(token: nil)
        if case .accept(let data) = handler.handle(requestData: Data(unauthRequest.utf8)) {
            let response = String(data: data, encoding: .utf8) ?? ""
            #expect(response.contains("s3pPLMBiTxaQ9kYGzzhZRbK+xOo="))
        } else {
            Issue.record("Expected accept")
        }
    }

    @Test func rejectsMissingTokenWhenAuthRequired() {
        let handler = WebSocketUpgradeHandler(token: "test-token")
        if case .reject(let data) = handler.handle(requestData: Data(unauthRequest.utf8)) {
            #expect(String(data: data, encoding: .utf8)?.hasPrefix("HTTP/1.1 401") == true)
        } else {
            Issue.record("Expected reject")
        }
    }

    @Test func rejectsBadToken() {
        let handler = WebSocketUpgradeHandler(token: "test-token")
        let badAuth = validRequest.replacingOccurrences(of: "test-token", with: "wrong-token")
        if case .reject(let data) = handler.handle(requestData: Data(badAuth.utf8)) {
            #expect(String(data: data, encoding: .utf8)?.hasPrefix("HTTP/1.1 401") == true)
        } else {
            Issue.record("Expected reject")
        }
    }

    @Test func acceptsInInsecureMode() {
        let handler = WebSocketUpgradeHandler(token: nil)
        if case .accept = handler.handle(requestData: Data(unauthRequest.utf8)) {
        } else {
            Issue.record("Expected accept in insecure mode")
        }
    }

    @Test func rejectsPostMethod() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let post = unauthRequest.replacingOccurrences(of: "GET ", with: "POST ")
        if case .reject = handler.handle(requestData: Data(post.utf8)) {
        } else {
            Issue.record("Expected reject for non-GET method")
        }
    }

    @Test func acceptsRootPath() {
        // hostPort and Bonjour service endpoints upgrade against "/" because
        // NWProtocolWebSocket cannot attach a path to those endpoints.
        let handler = WebSocketUpgradeHandler(token: nil)
        let rootPath = unauthRequest.replacingOccurrences(of: "GET /patternspace HTTP/1.1", with: "GET / HTTP/1.1")
        if case .accept = handler.handle(requestData: Data(rootPath.utf8)) {
        } else {
            Issue.record("Expected accept for root path")
        }
    }

    @Test func acceptsArbitraryPath() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let other = unauthRequest.replacingOccurrences(of: "/patternspace", with: "/other")
        if case .accept = handler.handle(requestData: Data(other.utf8)) {
        } else {
            Issue.record("Expected accept for arbitrary path")
        }
    }

    @Test func rejectsMalformedRequestLine() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let malformed = unauthRequest.replacingOccurrences(of: "GET /patternspace HTTP/1.1", with: "GET /patternspace")
        if case .reject = handler.handle(requestData: Data(malformed.utf8)) {
        } else {
            Issue.record("Expected reject for malformed request line")
        }
    }

    @Test func rejectsMissingConnectionUpgrade() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let missing = unauthRequest.replacingOccurrences(of: "Connection: Upgrade\r\n", with: "")
        if case .reject = handler.handle(requestData: Data(missing.utf8)) {
        } else {
            Issue.record("Expected reject for missing Connection: Upgrade")
        }
    }

    @Test func rejectsWrongWebSocketVersion() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let wrong = unauthRequest.replacingOccurrences(of: "Sec-WebSocket-Version: 13", with: "Sec-WebSocket-Version: 8")
        if case .reject = handler.handle(requestData: Data(wrong.utf8)) {
        } else {
            Issue.record("Expected reject for wrong WebSocket version")
        }
    }

    @Test func rejectsInvalidBase64Key() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let bad = unauthRequest.replacingOccurrences(of: "dGhlIHNhbXBsZSBub25jZQ==", with: "not-valid-base64!!!")
        if case .reject = handler.handle(requestData: Data(bad.utf8)) {
        } else {
            Issue.record("Expected reject for invalid base64 key")
        }
    }

    @Test func rejectsKeyWithWrongDecodedLength() {
        let handler = WebSocketUpgradeHandler(token: nil)
        let short = unauthRequest.replacingOccurrences(of: "dGhlIHNhbXBsZSBub25jZQ==", with: "dGVzdA==")
        if case .reject = handler.handle(requestData: Data(short.utf8)) {
        } else {
            Issue.record("Expected reject for key with wrong decoded length")
        }
    }
}
