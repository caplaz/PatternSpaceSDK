import Foundation
import PatternSpaceSDKCore

/// Client namespace for `pattern.*` JSON-RPC methods.
public final class PatternNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    /// Displays a pattern by protocol identifier.
    ///
    /// - Parameter id: Pattern identifier returned by `list` or `get`.
    public func display(id: String) async throws {
        struct Params: Encodable { let patternId: String }
        _ = try await session.send(method: "pattern.display",
                                   params: Params(patternId: id),
                                   via: transport)
    }

    /// Displays a solid color, optionally as a centered area patch.
    ///
    /// When `size` is omitted, the color fills the whole display. When `size`
    /// is provided, it represents the percentage of screen area to cover, using
    /// the same area-based convention as CalMAN. For example, `size: 10`
    /// displays a centered square covering 10% of the screen area.
    public func displayColor(_ color: PSColor, bitDepth: BitDepth, size: Double? = nil) async throws {
        struct Params: Encodable { let r: Double; let g: Double; let b: Double; let bitDepth: Int; let size: Double? }
        _ = try await session.send(
            method: "pattern.displayColor",
            params: Params(r: color.r, g: color.g, b: color.b, bitDepth: bitDepth.rawValue, size: size),
            via: transport
        )
    }

    /// Displays one or more normalized rectangles over a shared background.
    ///
    /// Rectangles use normalized display coordinates, where `0...1` maps to
    /// the current active display area.
    public func displayPatch(background: PSColor,
                             rectangles: [PatchRectangle],
                             bitDepth: BitDepth) async throws {
        struct ColorParams: Encodable { let r: Double; let g: Double; let b: Double }
        struct WireRectangleParams: Encodable {
            let color: ColorParams
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }
        struct Params: Encodable {
            let background: ColorParams
            let rectangles: [WireRectangleParams]
            let bitDepth: Int
        }

        _ = try await session.send(
            method: "pattern.displayPatch",
            params: Params(
                background: ColorParams(r: background.r, g: background.g, b: background.b),
                rectangles: rectangles.map {
                    WireRectangleParams(
                        color: ColorParams(r: $0.color.r, g: $0.color.g, b: $0.color.b),
                        x: $0.x,
                        y: $0.y,
                        width: $0.width,
                        height: $0.height
                    )
                },
                bitDepth: bitDepth.rawValue
            ),
            via: transport
        )
    }

    /// Clears the current JSON protocol pattern from the display.
    public func clear() async throws {
        struct Params: Encodable {}
        _ = try await session.send(method: "pattern.clear", params: Params(), via: transport)
    }

    /// Lists available patterns, optionally filtered by category.
    public func list(category: String? = nil, subcategory: String? = nil) async throws -> [PatternInfo] {
        struct Params: Encodable { let category: String?; let subcategory: String? }
        struct Response: Decodable { let patterns: [PatternInfo] }

        let result = try await session.send(
            method: "pattern.list",
            params: Params(category: category, subcategory: subcategory),
            via: transport
        )
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(Response.self, from: data).patterns
    }

    /// Returns metadata for one pattern.
    public func get(id: String) async throws -> PatternInfo {
        struct Params: Encodable { let patternId: String }
        let result = try await session.send(method: "pattern.get",
                                            params: Params(patternId: id),
                                            via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(PatternInfo.self, from: data)
    }
}
