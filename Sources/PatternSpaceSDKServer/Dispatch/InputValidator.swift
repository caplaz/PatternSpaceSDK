// Sources/PatternSpaceSDKServer/Dispatch/InputValidator.swift
import PatternSpaceSDKCore

public enum InputValidator {
    public static func validateColor(r: Double, g: Double, b: Double) throws {
        guard r.isFinite, g.isFinite, b.isFinite else {
            throw PSDispatchError(.invalidParams, message: "r, g, b must be finite numbers")
        }
        guard (0.0...1.0).contains(r), (0.0...1.0).contains(g), (0.0...1.0).contains(b) else {
            throw PSDispatchError(.invalidParams, message: "r, g, b must be in [0.0, 1.0]")
        }
    }

    public static func validateBitDepth(_ value: Int) throws {
        guard BitDepth(rawValue: value) != nil else {
            throw PSDispatchError(.invalidBitDepth)
        }
    }

    public static func validateRectangle(x: Int, y: Int, width: Int, height: Int,
                                         in resolution: Resolution) throws {
        guard width >= 1, height >= 1 else {
            throw PSDispatchError(.invalidParams, message: "width and height must be ≥ 1")
        }
        guard x >= 0, y >= 0 else {
            throw PSDispatchError(.invalidParams, message: "x and y must be ≥ 0")
        }
        guard x + width <= resolution.width, y + height <= resolution.height else {
            throw PSDispatchError(.invalidParams,
                message: "Rectangle (\(x)+\(width), \(y)+\(height)) exceeds display resolution \(resolution.width)×\(resolution.height)")
        }
    }

    public static func validatePatternId(_ id: String) throws {
        guard !id.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "patternId must not be empty")
        }
    }
}
