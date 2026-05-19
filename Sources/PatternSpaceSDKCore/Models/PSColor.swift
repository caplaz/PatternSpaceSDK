// Sources/PatternSpaceSDKCore/Models/PSColor.swift
import Foundation

public struct PSColor: Codable, Sendable, Equatable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }
}

public enum BitDepth: Int, Codable, Sendable, CaseIterable {
    case eight   = 8
    case ten     = 10
    case twelve  = 12
    case sixteen = 16
}

public struct NormalizedRectangle: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PatchRectangle: Codable, Sendable, Equatable {
    public let color: PSColor
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(color: PSColor, x: Double, y: Double, width: Double, height: Double) {
        self.color = color
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(color: PSColor, rectangle: NormalizedRectangle) {
        self.init(color: color, x: rectangle.x, y: rectangle.y, width: rectangle.width, height: rectangle.height)
    }
}

public struct PatchParams: Codable, Sendable, Equatable {
    public let background: PSColor
    public let rectangles: [PatchRectangle]
    public let bitDepth: BitDepth

    public init(background: PSColor, rectangles: [PatchRectangle], bitDepth: BitDepth) {
        self.background = background
        self.rectangles = rectangles
        self.bitDepth = bitDepth
    }
}
