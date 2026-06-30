import Foundation

/// Catégorie de matériel — table `categories`.
struct ItemCategory: Codable, Identifiable, Hashable {
    let id: String
    var name: String
}
