import Foundation
import Testing
@testable import PatternSpaceSDKServer

@Suite struct WebSocketFrameCodecTests {
    @Test func encodesShortTextFrame() {
        let payload = Data("hi".utf8)
        let frame = WebSocketFrame(opcode: .text, payload: payload)
        let encoded = WebSocketFrameCodec.encode(frame)
        #expect(encoded[0] == 0x81)
        #expect(encoded[1] == 0x02)
        #expect(encoded[2...3] == payload[...])
    }

    @Test func encodes126BytePayloadWith2ByteLength() {
        let payload = Data(repeating: 0x41, count: 126)
        let frame = WebSocketFrame(opcode: .binary, payload: payload)
        let encoded = WebSocketFrameCodec.encode(frame)
        #expect(encoded[1] == 126)
        let len = Int(encoded[2]) << 8 | Int(encoded[3])
        #expect(len == 126)
    }

    @Test func decodesMaskedClientFrame() {
        let payload = Data("test".utf8)
        let mask: [UInt8] = [0x37, 0xfa, 0x21, 0x3d]
        let masked = Data(payload.enumerated().map { $0.element ^ mask[$0.offset % 4] })
        var raw = Data([0x81, 0x84])
        raw.append(contentsOf: mask)
        raw.append(contentsOf: masked)

        if case .frame(let frame, _) = WebSocketFrameCodec.decode(from: raw) {
            #expect(frame.payload == payload)
        } else {
            Issue.record("Expected .frame")
        }
    }

    @Test func rejectsUnmaskedClientFrame() {
        let frame = WebSocketFrame(opcode: .text, payload: Data("hello".utf8))
        let encoded = WebSocketFrameCodec.encode(frame)
        if case .protocolError = WebSocketFrameCodec.decode(from: encoded) {
        } else {
            Issue.record("Expected .protocolError for unmasked client frame")
        }
    }

    @Test func returnsIncompleteForPartialData() {
        if case .incomplete = WebSocketFrameCodec.decode(from: Data([0x81])) {
        } else {
            Issue.record("Expected .incomplete")
        }
    }

    @Test func rejectsOversizedPayload() {
        var raw = Data([0x82, 0xff])
        let size = 65_537
        for shift in stride(from: 56, through: 0, by: -8) {
            raw.append(UInt8((size >> shift) & 0xff))
        }
        if case .oversized = WebSocketFrameCodec.decode(from: raw) {
        } else {
            Issue.record("Expected .oversized")
        }
    }

    @Test func encodesCloseFrame() {
        let frame = WebSocketFrame(opcode: .close, payload: Data())
        let encoded = WebSocketFrameCodec.encode(frame)
        #expect(encoded[0] == 0x88)
    }
}
