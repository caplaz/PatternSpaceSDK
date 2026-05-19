// Tests/PatternSpaceSDKCoreTests/JSONRPCTypesTests.swift
import Testing
import Foundation
@testable import PatternSpaceSDKCore

@Suite struct JSONRPCTypesTests {
    @Test func idDecodesString() throws {
        let id = try JSONDecoder().decode(JSONRPCId.self, from: Data(#""abc""#.utf8))
        #expect(id == .string("abc"))
    }
    @Test func idDecodesInteger() throws {
        let id = try JSONDecoder().decode(JSONRPCId.self, from: Data("7".utf8))
        #expect(id == .integer(7))
    }
    @Test func incomingRequestDecodes() throws {
        let json = #"{"jsonrpc":"2.0","id":"1","method":"pattern.display","params":{"patternId":"Color-One-Red"}}"#
        let req = try JSONDecoder().decode(IncomingRequest.self, from: Data(json.utf8))
        #expect(req.jsonrpc == "2.0")
        #expect(req.id == .string("1"))
        #expect(req.method == "pattern.display")
        #expect(req.params?.object?["patternId"] == .string("Color-One-Red"))
    }
    @Test func incomingRequestRejectsNullId() throws {
        let json = #"{"jsonrpc":"2.0","id":null,"method":"pattern.clear","params":{}}"#
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(IncomingRequest.self, from: Data(json.utf8))
        }
    }
    @Test func successResponseEncodesCorrectly() throws {
        let response = JSONRPCSuccessResponse(id: .string("1"), result: JSONValue.object(["patternId": .string("Color-One-Red")]))
        let data = try JSONEncoder().encode(response)
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(obj.object?["jsonrpc"] == .string("2.0"))
        #expect(obj.object?["id"] == .string("1"))
    }
    @Test func errorResponseEncodesCorrectly() throws {
        let payload = JSONRPCErrorPayload(code: -32002, message: "Pattern not found", data: nil)
        let response = JSONRPCErrorResponse(id: .string("1"), error: payload)
        let data = try JSONEncoder().encode(response)
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(obj.object?["error"]?.object?["code"] == .int(-32002))
    }
    @Test func parseErrorResponseUsesNullId() throws {
        let response = JSONRPCParseErrorResponse()
        let data = try JSONEncoder().encode(response)
        let obj = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(obj.object?["id"] == .null)
    }
}
