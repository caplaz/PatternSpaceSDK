// Sources/PatternSpaceSDKCore/Models/PatternInfo.swift
import Foundation

/// Metadata describing a built-in or app-provided PatternSpace pattern.
public struct PatternInfo: Codable, Sendable, Equatable, Identifiable {
    /// Stable protocol identifier used with `pattern.display` and `pattern.get`.
    public let id: String

    /// Human-readable pattern name.
    public let name: String

    /// Top-level grouping used by `pattern.list` filters.
    public let category: String

    /// Secondary grouping used by `pattern.list` filters.
    public let subcategory: String

    /// Creates a pattern metadata value.
    public init(id: String, name: String, category: String, subcategory: String) {
        self.id = id; self.name = name
        self.category = category; self.subcategory = subcategory
    }
}
