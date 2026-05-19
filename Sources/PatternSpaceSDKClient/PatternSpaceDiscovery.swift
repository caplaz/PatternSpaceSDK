import Foundation
import Network

public final class PatternSpaceDiscovery: @unchecked Sendable {
    private var browser: NWBrowser?

    public init() {}

    public func discover(timeout: TimeInterval = 5) async -> [PatternSpaceService] {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.patternspace.discovery")
            let accumulator = DiscoveryAccumulator()

            let browser = NWBrowser(for: .bonjour(type: "_patternspace._tcp", domain: nil), using: .tcp)
            self.browser = browser

            browser.browseResultsChangedHandler = { newResults, _ in
                for result in newResults {
                    if case .service(let name, _, _, _) = result.endpoint {
                        accumulator.add(PatternSpaceService(name: name, endpoint: result.endpoint, port: 7878))
                    }
                }
            }

            browser.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                browser.cancel()
                continuation.resume(returning: accumulator.services())
            }
        }
    }
}

private final class DiscoveryAccumulator: @unchecked Sendable {
    private var seen: [String: PatternSpaceService] = [:]
    private let lock = NSLock()

    func add(_ service: PatternSpaceService) {
        lock.lock()
        seen[service.name] = service
        lock.unlock()
    }

    func services() -> [PatternSpaceService] {
        lock.lock()
        defer { lock.unlock() }
        return Array(seen.values)
    }
}
