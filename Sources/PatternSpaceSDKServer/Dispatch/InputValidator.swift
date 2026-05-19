// Sources/PatternSpaceSDKServer/Dispatch/InputValidator.swift
import PatternSpaceSDKCore

public enum InputValidator {
    public static let maxPatchRectangles = 64

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

    public static func validateRectangle(x: Double, y: Double, width: Double, height: Double) throws {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite else {
            throw PSDispatchError(.invalidParams, message: "x, y, width, height must be finite numbers")
        }
        guard width > 0, height > 0 else {
            throw PSDispatchError(.invalidParams, message: "width and height must be > 0")
        }
        guard x >= 0, y >= 0, x + width <= 1.0, y + height <= 1.0 else {
            throw PSDispatchError(.invalidParams, message: "rectangle coordinates must fit within normalized display space")
        }
    }

    public static func validateRectangleCount(_ count: Int) throws {
        guard count > 0 else {
            throw PSDispatchError(.invalidParams, message: "rectangles must not be empty")
        }
        guard count <= maxPatchRectangles else {
            throw PSDispatchError(.invalidParams, message: "rectangles must contain at most \(maxPatchRectangles) items")
        }
    }

    public static func rectangleForCenteredPatch(sizePercent: Double?) throws -> NormalizedRectangle {
        let size = sizePercent ?? 100
        guard size.isFinite else {
            throw PSDispatchError(.invalidParams, message: "size must be a finite number")
        }
        guard size > 0, size <= 100 else {
            throw PSDispatchError(.invalidParams, message: "size must be in (0, 100]")
        }
        let side = (size / 100).squareRoot()
        let origin = (1 - side) / 2
        return NormalizedRectangle(x: origin, y: origin, width: side, height: side)
    }

    public static func validatePatternId(_ id: String) throws {
        guard !id.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "patternId must not be empty")
        }
    }
}
