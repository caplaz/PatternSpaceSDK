import Foundation
import PatternSpaceSDKCore

extension JSONRPCDispatcher {
    func handleSignalSnapshot(_ params: JSONValue?, context: OutputRequestContext) async throws -> JSONValue {
        guard let delegate, delegate.supportsSignalSnapshot else { throw PSDispatchError(.methodNotFound) }
        try requireNoParams(params)
        let response = try await delegate.signalSnapshot(context: context)
        return try JSONDecoder().decode(JSONValue.self, from: response.validatedData())
    }

    func handleSignalProbe(_ params: JSONValue?, context: OutputRequestContext) async throws -> JSONValue {
        guard let delegate, delegate.supportsSignalProbe else { throw PSDispatchError(.methodNotFound) }
        guard let guardValue = params?.object?["expectedContextGuard"]?.string,
              SignalProbeParams.isValidGuard(guardValue) else {
            throw PSDispatchError(.invalidParams, message: "expectedContextGuard must be a bounded nonempty printable token")
        }
        let patch = try InputValidator.patch(params)
        try requireSourceActive()
        try await delegate.displayProbe(.init(patch: patch, expectedContextGuard: guardValue), context: context)
        return .object([:])
    }

    /// Removes only unsupported new entries; the host's existing namespace and feature contracts remain intact.
    func filteredSignalCapabilities(_ capabilities: CapabilitiesResult) throws -> JSONValue {
        var object = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(capabilities)).object ?? [:]
        var namespaces = object["namespaces"]?.object ?? [:]
        var features = object["features"]?.object ?? [:]
        for (supported, namespace, method, feature) in [
            (delegate?.supportsSignalSnapshot == true, "device", "signalSnapshot", "signalSnapshot"),
            (delegate?.supportsSignalProbe == true, "pattern", "displayProbe", "signalProbe")
        ] {
            if supported { continue }
            if let methods = namespaces[namespace]?.array {
                namespaces[namespace] = .array(methods.filter { $0 != .string(method) })
            }
            features.removeValue(forKey: feature)
        }
        object["namespaces"] = .object(namespaces)
        object["features"] = .object(features)
        return .object(object)
    }
}
