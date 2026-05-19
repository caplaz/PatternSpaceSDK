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

public struct RectangleParams: Codable, Sendable, Equatable {
    public let foreground: PSColor
    public let background: PSColor
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let bitDepth: BitDepth

    public init(foreground: PSColor, background: PSColor,
                x: Int, y: Int, width: Int, height: Int, bitDepth: BitDepth) {
        self.foreground = foreground; self.background = background
        self.x = x; self.y = y; self.width = width; self.height = height
        self.bitDepth = bitDepth
    }
}
