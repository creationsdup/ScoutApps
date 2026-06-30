import Foundation

/// Origine d'une ligne de courses.
public enum ShoppingSource: String, Codable, Hashable {
    case auto       // généré depuis les menus
    case manual     // ajouté à la main
    public var label: String { self == .auto ? "Menus" : "Manuel" }
}

/// Ligne de la liste de courses d'un camp (table `shopping_items`).
public struct ShoppingItem: Codable, Identifiable, Hashable {
    public let id: String
    public var campId: String
    public var name: String
    public var quantity: Double?
    public var unit: String?
    public var checked: Bool
    public var source: ShoppingSource

    public init(
        id: String,
        campId: String,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        checked: Bool,
        source: ShoppingSource
    ) {
        self.id = id
        self.campId = campId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.checked = checked
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case name, quantity, unit, checked, source
    }
}
