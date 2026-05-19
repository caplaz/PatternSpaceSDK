// Tests/PatternSpaceSDKCoreTests/JSONValueTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKCore

@Suite struct JSONValueTests {
    @Test func decodesNull() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data("null".utf8))
        #expect(v == .null)
    }
    @Test func decodesBool() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data("true".utf8))
        #expect(v == .bool(true))
    }
    @Test func decodesInt() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data("42".utf8))
        #expect(v == .int(42))
    }
    @Test func decodesDouble() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data("3.14".utf8))
        if case .double(let d) = v { #expect(abs(d - 3.14) < 0.001) }
        else { Issue.record("Expected .double") }
    }
    @Test func decodesString() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data(#""hello""#.utf8))
        #expect(v == .string("hello"))
    }
    @Test func decodesObject() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"a":1}"#.utf8))
        #expect(v.object?["a"] == .int(1))
    }
    @Test func roundtripsObject() throws {
        let original: JSONValue = .object(["x": .int(1), "y": .string("hi")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == original)
    }
}
