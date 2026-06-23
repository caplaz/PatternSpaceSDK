import Foundation

/// A decoded WebSocket frame.
public struct WebSocketFrame: Sendable {
    /// Supported WebSocket opcodes used by the PatternSpace protocol.
    public enum Opcode: UInt8, Sendable {
        /// Continuation frame.
        case continuation = 0x0

        /// UTF-8 text frame containing JSON-RPC data.
        case text = 0x1

        /// Binary data frame.
        case binary = 0x2

        /// Connection close frame.
        case close = 0x8

        /// Ping control frame.
        case ping = 0x9

        /// Pong control frame.
        case pong = 0xa
    }

    /// Frame opcode.
    public let opcode: Opcode

    /// Unmasked payload bytes.
    public let payload: Data

    /// Whether this is the final frame in a message.
    public let fin: Bool

    /// Creates a WebSocket frame.
    public init(opcode: Opcode, payload: Data, fin: Bool = true) {
        self.opcode = opcode
        self.payload = payload
        self.fin = fin
    }
}

/// Result of attempting to decode one frame from a receive buffer.
public enum FrameDecodeResult: Sendable {
    /// A complete frame and the number of bytes consumed from the buffer.
    case frame(WebSocketFrame, consumed: Int)

    /// More bytes are needed before a full frame can be decoded.
    case incomplete

    /// The frame exceeds `WebSocketFrameCodec.maxPayloadBytes`.
    case oversized

    /// The buffer violates the WebSocket framing rules enforced by the SDK.
    case protocolError
}

/// Minimal WebSocket frame encoder and decoder used by `PatternSpaceServer`.
public enum WebSocketFrameCodec {
    /// Maximum accepted payload size for one WebSocket frame.
    public static let maxPayloadBytes = 65_536

    /// Encodes a server-to-client frame.
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

    /// Decodes one client-to-server frame from the beginning of a buffer.
    ///
    /// Client frames must be masked according to the WebSocket specification.
    ///
    /// Indexing is relative to `buffer.startIndex` throughout, and `consumed` is
    /// returned as a byte count (not an absolute index). This matters because
    /// `Data` preserves a non-zero `startIndex` after `removeFirst(_:)`, so a
    /// buffer holding the second-or-later frame on a connection does not start at
    /// index 0. Mixing absolute indices with `buffer.count` previously made the
    /// length guards unsatisfiable on such buffers, stalling multi-request
    /// connections (the frame decoded as perpetually `.incomplete`).
    public static func decode(from buffer: Data) -> FrameDecodeResult {
        let base = buffer.startIndex
        let available = buffer.count
        guard available >= 2 else { return .incomplete }

        let first = buffer[base]
        let second = buffer[base + 1]
        let fin = (first & 0x80) != 0
        guard let opcode = WebSocketFrame.Opcode(rawValue: first & 0x0f) else {
            return .protocolError
        }

        guard (second & 0x80) != 0 else { return .protocolError }

        var payloadLength = Int(second & 0x7f)
        var cursor = 2 // bytes consumed so far, relative to base

        if payloadLength == 126 {
            guard available >= cursor + 2 else { return .incomplete }
            payloadLength = Int(buffer[base + cursor]) << 8 | Int(buffer[base + cursor + 1])
            cursor += 2
        } else if payloadLength == 127 {
            guard available >= cursor + 8 else { return .incomplete }
            payloadLength = (0..<8).reduce(0) { ($0 << 8) | Int(buffer[base + cursor + $1]) }
            cursor += 8
        }

        guard payloadLength <= maxPayloadBytes else { return .oversized }
        guard available >= cursor + 4 else { return .incomplete }

        let maskKey = [
            buffer[base + cursor],
            buffer[base + cursor + 1],
            buffer[base + cursor + 2],
            buffer[base + cursor + 3]
        ]
        cursor += 4

        guard available >= cursor + payloadLength else { return .incomplete }
        let payloadStart = base + cursor
        var payload = Data(buffer[payloadStart..<(payloadStart + payloadLength)])
        for index in 0..<payload.count {
            payload[index] ^= maskKey[index % 4]
        }

        return .frame(WebSocketFrame(opcode: opcode, payload: payload, fin: fin),
                      consumed: cursor + payloadLength)
    }
}
