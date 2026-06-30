import Foundation

/// Origine d'une ligne de courses.
enum ShoppingSource: String, Codable, Hashable {
    case auto       // généré depuis les menus
    case manual     // ajouté à la main
    var label: String { self == .auto ? "Menus" : "Manuel" }
}

/// Ligne de la liste de courses d'un camp (table `shopping_items`).
struct ShoppingItem: Codable, Identifiable, Hashable {
    let id: String
    var campId: String
    var name: String
    var quantity: Double?
    var unit: String?
    var checked: Bool
    var source: ShoppingSource

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case name, quantity, unit, checked, source
    }
}
