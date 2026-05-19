import Foundation

public struct WebSocketFrame: Sendable {
    public enum Opcode: UInt8, Sendable {
        case continuation = 0x0
        case text = 0x1
        case binary = 0x2
        case close = 0x8
        case ping = 0x9
        case pong = 0xa
    }

    public let opcode: Opcode
    public let payload: Data
    public let fin: Bool

    public init(opcode: Opcode, payload: Data, fin: Bool = true) {
        self.opcode = opcode
        self.payload = payload
        self.fin = fin
    }
}

public enum FrameDecodeResult: Sendable {
    case frame(WebSocketFrame, consumed: Int)
    case incomplete
    case oversized
    case protocolError
}

public enum WebSocketFrameCodec {
    public static let maxPayloadBytes = 65_536

    public static func encode(_ frame: WebSocketFrame) -> Data {
        var out = Data()
        out.append((frame.fin ? 0x80 : 0x00) | frame.opcode.rawValue)

        let length = frame.payload.count
        if length < 126 {
            out.append(UInt8(length))
        } else if length <= 0xffff {
            out.append(126)
            out.append(UInt8((length >> 8) & 0xff))
            out.append(UInt8(length & 0xff))
        } else {
            out.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                out.append(UInt8((length >> shift) & 0xff))
            }
        }

        out.append(contentsOf: frame.payload)
        return out
    }

    public static func decode(from buffer: Data) -> FrameDecodeResult {
        guard buffer.count >= 2 else { return .incomplete }

        let first = buffer[buffer.startIndex]
        let second = buffer[buffer.startIndex + 1]
        let fin = (first & 0x80) != 0
        guard let opcode = WebSocketFrame.Opcode(rawValue: first & 0x0f) else {
            return .protocolError
        }

        guard (second & 0x80) != 0 else { return .protocolError }

        var payloadLength = Int(second & 0x7f)
        var offset = buffer.startIndex + 2

        if payloadLength == 126 {
            guard buffer.count >= offset + 2 else { return .incomplete }
            payloadLength = Int(buffer[offset]) << 8 | Int(buffer[offset + 1])
            offset += 2
        } else if payloadLength == 127 {
            guard buffer.count >= offset + 8 else { return .incomplete }
            payloadLength = (0..<8).reduce(0) { ($0 << 8) | Int(buffer[offset + $1]) }
            offset += 8
        }

        guard payloadLength <= maxPayloadBytes else { return .oversized }
        guard buffer.count >= offset + 4 else { return .incomplete }

        let maskKey = [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]]
        offset += 4

        guard buffer.count >= offset + payloadLength else { return .incomplete }
        var payload = Data(buffer[offset..<(offset + payloadLength)])
        for index in 0..<payload.count {
            payload[index] ^= maskKey[index % 4]
        }

        return .frame(WebSocketFrame(opcode: opcode, payload: payload, fin: fin),
                      consumed: offset + payloadLength)
    }
}
