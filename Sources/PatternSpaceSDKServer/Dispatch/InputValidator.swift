// Sources/PatternSpaceSDKServer/Dispatch/InputValidator.swift
import PatternSpaceSDKCore

/// Validation helpers shared by JSON-RPC dispatch handlers.
public enum InputValidator {
    /// Maximum number of rectangles accepted by `pattern.displayPatch`.
    public static let maxPatchRectangles = 64

    /// Validates normalized RGB color components.
    public static func validateColor(r: Double, g: Double, b: Double) throws {
        guard r.isFinite, g.isFinite, b.isFinite else {
            throw PSDispatchError(.invalidParams, message: "r, g, b must be finite numbers")
        }
        guard (0.0...1.0).contains(r), (0.0...1.0).contains(g), (0.0...1.0).contains(b) else {
            throw PSDispatchError(.invalidParams, message: "r, g, b must be in [0.0, 1.0]")
        }
    }

    /// Validates that an integer maps to a supported `BitDepth`.
    public static func validateBitDepth(_ value: Int) throws {
        guard BitDepth(rawValue: value) != nil else {
            throw PSDispatchError(.invalidBitDepth)
        }
    }

    /// Validates a rectangle in normalized display coordinates.
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

    /// Validates the number of rectangles in a patch request.
    public static func validateRectangleCount(_ count: Int) throws {
        guard count > 0 else {
            throw PSDispatchError(.invalidParams, message: "rectangles must not be empty")
        }
        guard count <= maxPatchRectangles else {
            throw PSDispatchError(.invalidParams, message: "rectangles must contain at most \(maxPatchRectangles) items")
        }
    }

    /// Converts a CalMAN-style area percentage into a centered square patch.
    ///
    /// `nil` means 100% of the screen. A value of `10` produces a centered
    /// square whose area covers 10% of the display.
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

    /// Validates that a pattern identifier is present.
    public static func validatePatternId(_ id: String) throws {
        guard !id.isEmpty else {
            throw PSDispatchError(.invalidParams, message: "patternId must not be empty")
        }
    }
}
