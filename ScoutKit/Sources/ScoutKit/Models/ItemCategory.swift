import Foundation

/// Catégorie de matériel — table `categories`.
public struct ItemCategory: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    /// Code de préfixe de tag (ex. "TEN"). Saisi en base.
    public var code: String?

    public init(id: String, name: String, code: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
    }
}
