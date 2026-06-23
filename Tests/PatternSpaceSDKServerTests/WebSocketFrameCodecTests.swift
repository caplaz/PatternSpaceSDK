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

    @Test func decodesSecondFrameAfterRemovingFirst() {
        // Reproduces the multi-request-per-connection flow: decode frame 1,
        // advance the buffer with removeFirst(consumed), then decode frame 2.
        // After removeFirst, Data keeps a non-zero startIndex, which previously
        // made the second decode return .incomplete forever.
        var buffer = Data()
        buffer.append(maskedTextFrame("first"))
        buffer.append(maskedTextFrame("second"))

        guard case .frame(let firstFrame, let firstConsumed) = WebSocketFrameCodec.decode(from: buffer) else {
            Issue.record("Expected first .frame")
            return
        }
        #expect(firstFrame.payload == Data("first".utf8))

        buffer.removeFirst(firstConsumed)
        #expect(buffer.startIndex != 0) // precondition the bug depended on

        guard case .frame(let secondFrame, let secondConsumed) = WebSocketFrameCodec.decode(from: buffer) else {
            Issue.record("Expected second .frame after removeFirst")
            return
        }
        #expect(secondFrame.payload == Data("second".utf8))

        buffer.removeFirst(secondConsumed)
        #expect(buffer.isEmpty)
    }

    @Test func consumedIsRelativeByteCountOnRebasedBuffer() {
        // consumed must be a byte count, not an absolute index, so callers can
        // removeFirst(consumed) regardless of the buffer's startIndex.
        var buffer = Data([0xAA, 0xBB, 0xCC]) // leading bytes that get removed
        let frame = maskedTextFrame("hi")
        buffer.append(frame)
        buffer.removeFirst(3)

        guard case .frame(_, let consumed) = WebSocketFrameCodec.decode(from: buffer) else {
            Issue.record("Expected .frame")
            return
        }
        #expect(consumed == frame.count)
    }

    private func maskedTextFrame(_ text: String) -> Data {
        let payload = Data(text.utf8)
        let mask: [UInt8] = [0x12, 0x34, 0x56, 0x78]
        let masked = Data(payload.enumerated().map { $0.element ^ mask[$0.offset % 4] })
        var raw = Data([0x81, 0x80 | UInt8(payload.count)])
        raw.append(contentsOf: mask)
        raw.append(contentsOf: masked)
        return raw
    }
}
