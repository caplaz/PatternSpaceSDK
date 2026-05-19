// Sources/PatternSpaceSDKCore/Models/PSColor.swift
import Foundation

/// A normalized RGB color used by PatternSpace protocol methods.
///
/// Component values are expected to be finite numbers in the closed range
/// `0.0...1.0`. Server-side validators reject values outside that range.
public struct PSColor: Codable, Sendable, Equatable {
    /// Red channel, normalized to `0.0...1.0`.
    public let r: Double

    /// Green channel, normalized to `0.0...1.0`.
    public let g: Double

    /// Blue channel, normalized to `0.0...1.0`.
    public let b: Double

    /// Creates a normalized RGB color.
    public init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }
}

/// Supported output bit depths for generated patterns and color patches.
public enum BitDepth: Int, Codable, Sendable, CaseIterable {
    /// 8 bits per channel.
    case eight   = 8

    /// 10 bits per channel.
    case ten     = 10

    /// 12 bits per channel.
    case twelve  = 12

    /// 16 bits per channel.
    case sixteen = 16
}

/// A rectangle described in normalized display coordinates.
///
/// `x` and `y` are the top-left origin. `width` and `height` are fractions of
/// the active display area. For example, a centered 10% area patch has a side
/// length of `sqrt(0.10)`.
public struct NormalizedRectangle: Codable, Sendable, Equatable {
    /// Horizontal origin as a fraction of display width.
    public let x: Double

    /// Vertical origin as a fraction of display height.
    public let y: Double

    /// Rectangle width as a fraction of display width.
    public let width: Double

    /// Rectangle height as a fraction of display height.
    public let height: Double

    /// Creates a normalized rectangle.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A colored rectangle for `pattern.displayPatch`.
public struct PatchRectangle: Codable, Sendable, Equatable {
    /// Color rendered inside the rectangle.
    public let color: PSColor

    /// Horizontal origin as a fraction of display width.
    public let x: Double

    /// Vertical origin as a fraction of display height.
    public let y: Double

    /// Rectangle width as a fraction of display width.
    public let width: Double

    /// Rectangle height as a fraction of display height.
    public let height: Double

    /// Creates a colored rectangle from normalized display coordinates.
    public init(color: PSColor, x: Double, y: Double, width: Double, height: Double) {
        self.color = color
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Creates a colored rectangle from a `NormalizedRectangle` value.
    public init(color: PSColor, rectangle: NormalizedRectangle) {
        self.init(color: color, x: rectangle.x, y: rectangle.y, width: rectangle.width, height: rectangle.height)
    }
}

/// Parameters for the `pattern.displayPatch` JSON-RPC method.
///
/// A patch request contains one shared background color and one or more colored
/// rectangles layered on top of it.
public struct PatchParams: Codable, Sendable, Equatable {
    /// Color used outside the patch rectangles.
    public let background: PSColor

    /// Rectangles to render over the background.
    public let rectangles: [PatchRectangle]

    /// Output bit depth requested for the rendered patch.
    public let bitDepth: BitDepth

    /// Creates a patch request.
    public init(background: PSColor, rectangles: [PatchRectangle], bitDepth: BitDepth) {
        self.background = background
        self.rectangles = rectangles
        self.bitDepth = bitDepth
    }
}
