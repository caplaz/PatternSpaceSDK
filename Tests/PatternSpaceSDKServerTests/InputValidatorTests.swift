// Tests/PatternSpaceSDKServerTests/InputValidatorTests.swift
import Testing
@testable import PatternSpaceSDKServer
import PatternSpaceSDKCore

@Suite struct InputValidatorTests {
    @Test func validColorPasses() {
        #expect(throws: Never.self) {
            try InputValidator.validateColor(r: 0.5, g: 0.0, b: 1.0)
        }
    }
    @Test func colorAboveOneRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateColor(r: 1.1, g: 0, b: 0)
        }
    }
    @Test func colorBelowZeroRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateColor(r: 0, g: -0.1, b: 0)
        }
    }
    @Test func nanColorRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateColor(r: Double.nan, g: 0, b: 0)
        }
    }
    @Test func infinityColorRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateColor(r: Double.infinity, g: 0, b: 0)
        }
    }
    @Test func validBitDepthPasses() {
        for depth in [8, 10, 12, 16] {
            #expect(throws: Never.self) { try InputValidator.validateBitDepth(depth) }
        }
    }
    @Test func invalidBitDepthRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateBitDepth(11)
        }
    }
    @Test func validNormalizedRectanglePasses() {
        #expect(throws: Never.self) {
            try InputValidator.validateRectangle(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        }
    }
    @Test func normalizedRectangleWidthZeroRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateRectangle(x: 0, y: 0, width: 0, height: 0.5)
        }
    }
    @Test func normalizedRectangleOutOfBoundsRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateRectangle(x: 0.75, y: 0, width: 0.5, height: 0.5)
        }
    }
    @Test func normalizedRectangleNaNRejected() {
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateRectangle(x: Double.nan, y: 0, width: 0.5, height: 0.5)
        }
    }
    @Test func displayColorSizeUsesCalMANAreaPercentage() throws {
        let rect = try InputValidator.rectangleForCenteredPatch(sizePercent: 10)
        #expect(abs(rect.x - 0.341886) < 0.0001)
        #expect(abs(rect.y - 0.341886) < 0.0001)
        #expect(abs(rect.width - 0.316227) < 0.0001)
        #expect(abs(rect.height - 0.316227) < 0.0001)
    }
    @Test func displayColorSizeDefaultsToFullScreenWhenMissing() throws {
        let rect = try InputValidator.rectangleForCenteredPatch(sizePercent: nil)
        #expect(rect == NormalizedRectangle(x: 0, y: 0, width: 1, height: 1))
    }
    @Test func displayColorSizeAboveHundredRejected() {
        #expect(throws: PSDispatchError.self) {
            _ = try InputValidator.rectangleForCenteredPatch(sizePercent: 101)
        }
    }
    @Test func validPatternIdPasses() {
        #expect(throws: Never.self) { try InputValidator.validatePatternId("Color-One-Red") }
    }
    @Test func emptyPatternIdRejected() {
        #expect(throws: PSDispatchError.self) { try InputValidator.validatePatternId("") }
    }
}
