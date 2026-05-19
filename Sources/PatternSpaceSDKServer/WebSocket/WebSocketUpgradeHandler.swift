import CryptoKit
import Foundation

/// Result of a WebSocket upgrade attempt.
public enum UpgradeResult: Sendable {
    /// Upgrade accepted with an HTTP 101 response.
    case accept(Data)

    /// Upgrade rejected with an HTTP error response.
    case reject(Data)
}

/// Validates WebSocket upgrade requests for the PatternSpace endpoint.
public struct WebSocketUpgradeHandler: Sendable {
    private let token: String?

    /// Creates an upgrade handler.
    ///
    /// - Parameter token: Optional bearer token required in the `Authorization`
    ///   header.
    public init(token: String?) {
        self.token = token
    }

    /// Validates an HTTP upgrade request and returns the response bytes.
    public func handle(requestData: Data) -> UpgradeResult {
        guard let text = String(data: requestData, encoding: .utf8) else {
            return .reject(httpResponse("400 Bad Request", headers: [:]))
        }

        let lines = text.components(separatedBy: "\r\n")
        let headers = parseHeaders(lines)

        guard let requestLine = lines.first,
              requestLine == "GET /patternspace HTTP/1.1" else {
            return .reject(httpResponse("400 Bad Request", headers: [:]))
        }

        guard headers["upgrade"]?.lowercased() == "websocket",
              headers["connection"]?.lowercased().contains("upgrade") == true,
              headers["sec-websocket-version"] == "13",
              let key = headers["sec-websocket-key"] else {
            return .reject(httpResponse("400 Bad Request", headers: [:]))
        }

        guard let keyData = Data(base64Encoded: key), keyData.count == 16 else {
            return .reject(httpResponse("400 Bad Request", headers: [:]))
        }

        if let token {
            guard constantTimeEquals(headers["authorization"], "Bearer \(token)") else {
                return .reject(httpResponse("401 Unauthorized", headers: [:]))
            }
        }

        return .accept(httpResponse("101 Switching Protocols", headers: [
            "Upgrade": "websocket",
            "Connection": "Upgrade",
            "Sec-WebSocket-Accept": acceptKey(for: key),
        ]))
    }

    private func parseHeaders(_ lines: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).lowercased().trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    private func acceptKey(for key: String) -> String {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let hash = Insecure.SHA1.hash(data: Data((key + magic).utf8))
        return Data(hash).base64EncodedString()
    }

    private func constantTimeEquals(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        var difference = left.count ^ right.count
        for index in 0..<max(left.count, right.count) {
            let leftByte = index < left.count ? left[index] : 0
            let rightByte = index < right.count ? right[index] : 0
            difference |= Int(leftByte ^ rightByte)
        }
        return difference == 0
    }

    private func httpResponse(_ status: String, headers: [String: String]) -> Data {
        var response = "HTTP/1.1 \(status)\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        return Data(response.utf8)
    }
}
