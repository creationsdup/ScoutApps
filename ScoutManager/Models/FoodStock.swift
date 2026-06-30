import Foundation

/// Denrée en réserve pour un camp (table `food_stock`).
struct FoodStockItem: Codable, Identifiable, Hashable {
    let id: String
    var campId: String
    var name: String
    var quantity: Double?
    var unit: String?
    var expiryDate: String?     // "yyyy-MM-dd"
    var location: String?

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case name, quantity, unit
        case expiryDate = "expiry_date"
        case location
    }
}

/// État de péremption dérivé de `expiryDate` (pour l'alerte visuelle).
enum ExpiryStatus {
    case none        // pas de date
    case ok          // > 7 jours
    case soon        // 0..7 jours
    case expired     // date passée

    var label: String? {
        switch self {
        case .none: return nil
        case .ok:   return nil
        case .soon: return "Bientôt périmé"
        case .expired: return "Périmé"
        }
    }
}
