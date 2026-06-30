import Foundation

/// Catégorie de matériel — table `categories`.
public struct ItemCategory: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
