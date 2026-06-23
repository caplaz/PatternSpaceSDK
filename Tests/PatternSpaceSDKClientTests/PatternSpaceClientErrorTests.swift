import Testing
import PatternSpaceSDKClient

@Suite struct PatternSpaceClientErrorTests {
    @Test func disconnectedErrorDescription() {
        #expect(PatternSpaceClientError.disconnected.errorDescription == "The server closed the connection")
    }

    @Test func disconnectedLocalizedDescription() {
        // Verify the LocalizedError conformance surfaces through the base Error protocol,
        // so callers using error.localizedDescription (e.g. RemoteClientModel) get a readable string.
        let error: Error = PatternSpaceClientError.disconnected
        #expect(error.localizedDescription == "The server closed the connection")
    }
}
