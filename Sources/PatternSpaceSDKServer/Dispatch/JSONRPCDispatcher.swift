// Sources/PatternSpaceSDKServer/Dispatch/JSONRPCDispatcher.swift
import Foundation
import PatternSpaceSDKCore

enum JSONRPCRoute: String, CaseIterable {
    case capabilitiesList = "capabilities.list"
    case deviceInfo = "device.info"
    case deviceStatus = "device.status"
    case patternList = "pattern.list"
    case patternGet = "pattern.get"
    case patternDisplay = "pattern.display"
    case patternDisplayColor = "pattern.displayColor"
    case patternDisplayPatch = "pattern.displayPatch"
    case patternClear = "pattern.clear"
    case displayList = "display.list"
    case displaySetPeakWhite = "display.setPeakWhite"
    case displayListOutputColorPresets = "display.listOutputColorPresets"
    case displayGetOutputColorPreset = "display.getOutputColorPreset"
    case displaySetOutputColorPreset = "display.setOutputColorPreset"
    case displaySetMeasurementRange = "display.setMeasurementRange"

    var namespace: String {
        rawValue.split(separator: ".", maxSplits: 1).map(String.init)[0]
    }

    var methodName: String {
        rawValue.split(separator: ".", maxSplits: 1).map(String.init)[1]
    }
}

/// Dispatches validated JSON-RPC requests to a `PatternSpaceServerDelegate`.
///
/// This type owns protocol-level request validation, method routing, and
/// JSON-RPC error response construction.
public final class JSONRPCDispatcher: @unchecked Sendable {
    private weak var delegate: (any PatternSpaceServerDelegate)?

    /// Creates a dispatcher for a server delegate.
    public init(delegate: any PatternSpaceServerDelegate) {
        self.delegate = delegate
    }

    /// Methods advertised by `capabilities.list`, grouped by namespace.
    public static let routeManifest: [String: [String]] = {
        var manifest: [String: [String]] = [:]
        for route in JSONRPCRoute.allCases {
            manifest[route.namespace, default: []].append(route.methodName)
        }
        return manifest
    }()

    /// Handles one raw JSON-RPC request payload and returns an encoded response.
    public func dispatch(_ data: Data) async -> Data {
        // Stage 1: JSON syntax. Any failure → -32700, id is null per spec §5.
        guard let raw = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return errorResponseNullId(code: .parseError)
        }
        // Stage 2: envelope validation. Errors carry a recovered id when possible.
        guard case .object(let obj) = raw else {
            // Root is array (batch) or scalar.
            return errorResponseNullId(code: .invalidRequest, message: "Batch requests are not supported")
        }
        // Try to recover id for error responses before full validation.
        let recoveredId = extractId(from: obj)
        guard obj["jsonrpc"]?.string == "2.0" else {
            // Use recovered id when available; null only when id is absent/invalid.
            return errorResponseOptional(id: recoveredId, code: .invalidRequest, message: "jsonrpc must be '2.0'")
        }
        guard let method = obj["method"]?.string, !method.isEmpty else {
            return errorResponseOptional(id: recoveredId, code: .invalidRequest, message: "method is required")
        }
        guard let id = recoveredId else {
            // id missing, null, or non-string/int — client notification not supported.
            return errorResponseNullId(code: .invalidRequest, message: "id is required and must not be null")
        }
        if method.hasPrefix("rpc.") {
            return errorResponse(id: id, code: .methodNotFound)
        }
        let params = obj["params"]
        do {
            let result = try await route(method: method, params: params)
            return encode(JSONRPCSuccessResponse(id: id, result: result))
        } catch let e as PSDispatchError {
            return errorResponse(id: id, code: e.code, message: e.message, data: e.data)
        } catch {
            return errorResponse(id: id, code: .internalError)
        }
    }

    private func extractId(from obj: [String: JSONValue]) -> JSONRPCId? {
        switch obj["id"] {
        case .string(let s): return .string(s)
        case .int(let i):    return .integer(i)
        default:             return nil   // null, missing, or non-string/int
        }
    }

    // MARK: - Routing

    private func route(method: String, params: JSONValue?) async throws -> JSONValue {
        guard let route = JSONRPCRoute(rawValue: method) else {
            throw PSDispatchError(.methodNotFound)
        }
        switch route {
        case .capabilitiesList: return try await handleCapabilities()
        case .patternDisplay: return try await handleDisplay(params)
        case .patternDisplayColor: return try await handleDisplayColor(params)
        case .patternDisplayPatch: return try await handleDisplayPatch(params)
        case .patternClear: return try await handleClear()
        case .patternList: return try await handleList(params)
        case .patternGet: return try await handleGet(params)
        case .deviceInfo: return try await handleDeviceInfo()
        case .deviceStatus: return try await handleDeviceStatus()
        case .displayList: return try await handleDisplayList()
        case .displaySetPeakWhite: return try await handleSetPeakWhite(params)
        case .displayListOutputColorPresets: return try await handleListOutputColorPresets(params)
        case .displayGetOutputColorPreset: return try await handleGetOutputColorPreset(params)
        case .displaySetOutputColorPreset: return try await handleSetOutputColorPreset(params)
        case .displaySetMeasurementRange: return try await handleSetMeasurementRange(params)
        }
    }

    // MARK: - Write handlers

    private func requireSourceActive() throws {
        guard delegate?.isSourceActive == true else { throw PSDispatchError(.sourceNotActive) }
    }

    private func handleDisplay(_ params: JSONValue?) async throws -> JSONValue {
        guard let id = params?.object?["patternId"]?.string else {
            throw PSDispatchError(.invalidParams, message: "patternId (string) is required")
        }
        try InputValidator.validatePatternId(id)
        try requireSourceActive()
        try await delegate?.displayPattern(id: id)
        return .object(["patternId": .string(id)])
    }

    private func handleDisplayColor(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        guard let r = obj["r"]?.number, let g = obj["g"]?.number, let b = obj["b"]?.number,
              let bdInt = obj["bitDepth"]?.int else {
            throw PSDispatchError(.invalidParams, message: "r, g, b (numbers) and bitDepth (int) are required")
        }
        try InputValidator.validateColor(r: r, g: g, b: b)
        try InputValidator.validateBitDepth(bdInt)
        let bitDepth = BitDepth(rawValue: bdInt)!
        try requireSourceActive()
        if let size = obj["size"]?.number {
            let rect = try InputValidator.rectangleForCenteredPatch(sizePercent: size)
            let patch = PatchParams(
                background: PSColor(r: 0, g: 0, b: 0),
                rectangles: [PatchRectangle(color: PSColor(r: r, g: g, b: b), rectangle: rect)],
                bitDepth: bitDepth
            )
            try await delegate?.displayPatch(patch)
        } else {
            try await delegate?.displayColor(PSColor(r: r, g: g, b: b), bitDepth: bitDepth)
        }
        return .object([:])
    }

    private func handleDisplayPatch(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        guard let bg = obj["background"]?.object,
              let br = bg["r"]?.number, let bg_g = bg["g"]?.number, let bb = bg["b"]?.number,
              let rectValues = obj["rectangles"]?.array,
              let bdInt = obj["bitDepth"]?.int else {
            throw PSDispatchError(.invalidParams, message: "background, rectangles, and bitDepth are required")
        }
        try InputValidator.validateColor(r: br, g: bg_g, b: bb)
        try InputValidator.validateBitDepth(bdInt)
        try InputValidator.validateRectangleCount(rectValues.count)
        guard let bitDepth = BitDepth(rawValue: bdInt) else { throw PSDispatchError(.invalidBitDepth) }

        let rectangles = try rectValues.map { value -> PatchRectangle in
            guard let obj = value.object,
                  let colorObject = obj["color"]?.object,
                  let r = colorObject["r"]?.number,
                  let g = colorObject["g"]?.number,
                  let b = colorObject["b"]?.number,
                  let x = obj["x"]?.number,
                  let y = obj["y"]?.number,
                  let width = obj["width"]?.number,
                  let height = obj["height"]?.number else {
                throw PSDispatchError(.invalidParams, message: "each rectangle requires color, x, y, width, and height")
            }
            try InputValidator.validateColor(r: r, g: g, b: b)
            try InputValidator.validateRectangle(x: x, y: y, width: width, height: height)
            return PatchRectangle(color: PSColor(r: r, g: g, b: b), x: x, y: y, width: width, height: height)
        }

        try requireSourceActive()
        try await delegate?.displayPatch(PatchParams(
            background: PSColor(r: br, g: bg_g, b: bb),
            rectangles: rectangles,
            bitDepth: bitDepth
        ))
        return .object([:])
    }

    private func handleClear() async throws -> JSONValue {
        try requireSourceActive()
        try await delegate?.clearDisplay()
        return .object([:])
    }

    // MARK: - Read handlers

    private func handleList(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        let category    = obj["category"]?.string
        let subcategory = obj["subcategory"]?.string
        let patterns = try await delegate?.listPatterns(category: category, subcategory: subcategory) ?? []
        let items: [JSONValue] = patterns.map { p in
            .object(["id": .string(p.id), "name": .string(p.name),
                     "category": .string(p.category), "subcategory": .string(p.subcategory)])
        }
        return .object(["patterns": .array(items)])
    }

    private func handleGet(_ params: JSONValue?) async throws -> JSONValue {
        guard let id = params?.object?["patternId"]?.string else {
            throw PSDispatchError(.invalidParams, message: "patternId (string) is required")
        }
        try InputValidator.validatePatternId(id)
        guard let p = try await delegate?.getPattern(id: id) else {
            throw PSDispatchError(.patternNotFound, data: .object(["patternId": .string(id)]))
        }
        return .object(["id": .string(p.id), "name": .string(p.name),
                         "category": .string(p.category), "subcategory": .string(p.subcategory)])
    }

    private func handleDeviceInfo() async throws -> JSONValue {
        guard let info = try await delegate?.deviceInfo() else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(info)
    }

    private func handleDeviceStatus() async throws -> JSONValue {
        guard let status = try await delegate?.deviceStatus() else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(status)
    }

    private func handleCapabilities() async throws -> JSONValue {
        guard let capabilities = try await delegate?.capabilities() else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(capabilities)
    }

    // MARK: - Display handlers

    private func handleDisplayList() async throws -> JSONValue {
        let result = try await delegate?.listDisplays()
            ?? DisplayListResult(platform: .macOS, selectedDisplayId: nil, displays: [])
        return try encodeToJSONValue(result)
    }

    private func handleSetPeakWhite(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        guard let displayId = obj["displayId"]?.string, !displayId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "displayId (string) is required")
        }
        guard let peakWhite = obj["peakWhite"]?.number else {
            throw PSDispatchError(.invalidParams, message: "peakWhite (number) is required")
        }
        try InputValidator.validatePeakWhite(peakWhite)
        guard let display = try await delegate?.setPeakWhite(SetPeakWhiteParams(displayId: displayId, peakWhite: peakWhite)) else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(display)
    }

    private func handleListOutputColorPresets(_ params: JSONValue?) async throws -> JSONValue {
        guard let displayId = params?.object?["displayId"]?.string, !displayId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "displayId (string) is required")
        }
        guard let result = try await delegate?.listOutputColorPresets(displayId: displayId) else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(result)
    }

    private func handleGetOutputColorPreset(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        guard let displayId = obj["displayId"]?.string, !displayId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "displayId (string) is required")
        }
        guard let presetId = obj["presetId"]?.string, !presetId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "presetId (string) is required")
        }
        guard let result = try await delegate?.getOutputColorPreset(
            GetOutputColorPresetParams(
                displayId: displayId,
                presetId: OutputColorPresetID(rawValue: presetId)
            )
        ) else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(result)
    }

    private func handleSetOutputColorPreset(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        guard let displayId = obj["displayId"]?.string, !displayId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "displayId (string) is required")
        }
        guard let presetId = obj["presetId"]?.string, !presetId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "presetId (string) is required")
        }
        guard let result = try await delegate?.setOutputColorPreset(
            SetOutputColorPresetParams(
                displayId: displayId,
                presetId: OutputColorPresetID(rawValue: presetId)
            )
        ) else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(result)
    }

    private func handleSetMeasurementRange(_ params: JSONValue?) async throws -> JSONValue {
        let obj = params?.object ?? [:]
        guard let displayId = obj["displayId"]?.string, !displayId.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "displayId (string) is required")
        }
        guard let measurementRange = obj["measurementRange"]?.string,
              !measurementRange.isEmpty else {
            throw PSDispatchError(
                .invalidParams,
                message: "measurementRange (string) is required"
            )
        }
        guard let result = try await delegate?.setMeasurementRange(
            SetMeasurementRangeParams(
                displayId: displayId,
                measurementRange: OutputColorPresetMeasurementRange(
                    rawValue: measurementRange
                )
            )
        ) else {
            throw PSDispatchError(.internalError)
        }
        return try encodeToJSONValue(result)
    }

    // MARK: - Helpers

    private func errorResponse(id: JSONRPCId, code: PSErrorCode,
                                message: String? = nil, data: JSONValue? = nil) -> Data {
        let payload = JSONRPCErrorPayload(code: code.rawValue,
                                          message: message ?? code.defaultMessage,
                                          data: data)
        return encode(JSONRPCErrorResponse(id: id, error: payload))
    }

    // Uses id when recoverable; falls back to null id only when id is absent/invalid.
    private func errorResponseOptional(id: JSONRPCId?, code: PSErrorCode, message: String? = nil) -> Data {
        if let id { return errorResponse(id: id, code: code, message: message) }
        return errorResponseNullId(code: code, message: message)
    }

    // Used only when id truly cannot be recovered (batch root, JSON syntax error, missing/null id).
    private func errorResponseNullId(code: PSErrorCode, message: String? = nil) -> Data {
        struct NullIdError: Encodable {
            let jsonrpc = "2.0"; let id: JSONValue = .null; let error: JSONRPCErrorPayload
        }
        let payload = JSONRPCErrorPayload(code: code.rawValue, message: message ?? code.defaultMessage)
        return encode(NullIdError(error: payload))
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private func encodeToJSONValue<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}
