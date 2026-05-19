// Sources/PatternSpaceSDKCore/Models/PatternInfo.swift
import Foundation

public struct PatternInfo: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let subcategory: String

    public init(id: String, name: String, category: String, subcategory: String) {
        self.id = id; self.name = name
        self.category = category; self.subcategory = subcategory
    }
}
