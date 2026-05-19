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

    public func displayColor(_ color: PSColor, bitDepth: BitDepth) async throws {
        struct Params: Encodable { let r: Double; let g: Double; let b: Double; let bitDepth: Int }
        _ = try await session.send(
            method: "pattern.displayColor",
            params: Params(r: color.r, g: color.g, b: color.b, bitDepth: bitDepth.rawValue),
            via: transport
        )
    }

    public func displayRectangle(foreground: PSColor,
                                 background: PSColor,
                                 x: Int,
                                 y: Int,
                                 width: Int,
                                 height: Int,
                                 bitDepth: BitDepth) async throws {
        struct ColorParams: Encodable { let r: Double; let g: Double; let b: Double }
        struct Params: Encodable {
            let foreground: ColorParams
            let background: ColorParams
            let x: Int
            let y: Int
            let width: Int
            let height: Int
            let bitDepth: Int
        }

        _ = try await session.send(
            method: "pattern.displayRectangle",
            params: Params(
                foreground: ColorParams(r: foreground.r, g: foreground.g, b: foreground.b),
                background: ColorParams(r: background.r, g: background.g, b: background.b),
                x: x,
                y: y,
                width: width,
                height: height,
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
