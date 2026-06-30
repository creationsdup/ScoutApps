import Foundation

/// Sous-catégorie de matériel — table `subcategories` (niveau 2, rattachée à une catégorie).
public struct Subcategory: Codable, Identifiable, Hashable {
    public let id: String
    public var categoryId: String
    public var name: String

    public init(id: String, categoryId: String, name: String) {
        self.id = id
        self.categoryId = categoryId
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
    }
}
