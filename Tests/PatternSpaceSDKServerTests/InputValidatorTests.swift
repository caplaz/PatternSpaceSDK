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
    @Test func validRectanglePasses() {
        let res = Resolution(width: 3840, height: 2160)
        #expect(throws: Never.self) {
            try InputValidator.validateRectangle(x: 0, y: 0, width: 1920, height: 1080, in: res)
        }
    }
    @Test func rectangleWidthZeroRejected() {
        let res = Resolution(width: 3840, height: 2160)
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateRectangle(x: 0, y: 0, width: 0, height: 1080, in: res)
        }
    }
    @Test func rectangleOutOfBoundsRejected() {
        let res = Resolution(width: 1920, height: 1080)
        #expect(throws: PSDispatchError.self) {
            try InputValidator.validateRectangle(x: 100, y: 0, width: 1900, height: 1080, in: res)
        }
    }
    @Test func validPatternIdPasses() {
        #expect(throws: Never.self) { try InputValidator.validatePatternId("Color-One-Red") }
    }
    @Test func emptyPatternIdRejected() {
        #expect(throws: PSDispatchError.self) { try InputValidator.validatePatternId("") }
    }
}
