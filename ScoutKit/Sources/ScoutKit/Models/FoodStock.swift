import Foundation

/// Denrée en réserve pour un camp (table `food_stock`).
public struct FoodStockItem: Codable, Identifiable, Hashable {
    public let id: String
    public var campId: String
    public var name: String
    public var quantity: Double?
    public var unit: String?
    public var expiryDate: String?     // "yyyy-MM-dd"
    public var location: String?

    public init(
        id: String,
        campId: String,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        expiryDate: String? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.campId = campId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.expiryDate = expiryDate
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case name, quantity, unit
        case expiryDate = "expiry_date"
        case location
    }
}

/// État de péremption dérivé de `expiryDate` (pour l'alerte visuelle).
public enum ExpiryStatus {
    case none        // pas de date
    case ok          // > 7 jours
    case soon        // 0..7 jours
    case expired     // date passée

    public var label: String? {
        switch self {
        case .none: return nil
        case .ok:   return nil
        case .soon: return "Bientôt périmé"
        case .expired: return "Périmé"
        }
    }
}
