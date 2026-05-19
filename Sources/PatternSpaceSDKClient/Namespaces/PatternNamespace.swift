import Foundation
import PatternSpaceSDKCore

public final class PatternNamespace: Sendable {
    private let session: JSONRPCSession
    private let transport: WebSocketTransport

    init(session: JSONRPCSession, transport: WebSocketTransport) {
        self.session = session
        self.transport = transport
    }

    public func display(id: String) async throws {
        struct Params: Encodable { let patternId: String }
        _ = try await session.send(method: "pattern.display",
                                   params: Params(patternId: id),
                                   via: transport)
    }

    public func displayColor(_ color: PSColor, bitDepth: BitDepth, size: Double? = nil) async throws {
        struct Params: Encodable { let r: Double; let g: Double; let b: Double; let bitDepth: Int; let size: Double? }
        _ = try await session.send(
            method: "pattern.displayColor",
            params: Params(r: color.r, g: color.g, b: color.b, bitDepth: bitDepth.rawValue, size: size),
            via: transport
        )
    }

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

    public func clear() async throws {
        struct Params: Encodable {}
        _ = try await session.send(method: "pattern.clear", params: Params(), via: transport)
    }

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

    public func get(id: String) async throws -> PatternInfo {
        struct Params: Encodable { let patternId: String }
        let result = try await session.send(method: "pattern.get",
                                            params: Params(patternId: id),
                                            via: transport)
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(PatternInfo.self, from: data)
    }
}
