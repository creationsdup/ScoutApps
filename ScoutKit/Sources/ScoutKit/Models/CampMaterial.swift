import Foundation

/// Ligne de chargement matériel d'un camp (table `camp_materials`).
public struct CampMaterial: Codable, Identifiable, Hashable {
    public let campId: String
    public let inventoryItemId: String
    public var addedAt: String?
    public var id: String { inventoryItemId }   // unique par camp
    public init(campId: String, inventoryItemId: String, addedAt: String? = nil) {
        self.campId = campId; self.inventoryItemId = inventoryItemId; self.addedAt = addedAt
    }
    enum CodingKeys: String, CodingKey {
        case campId = "camp_id"
        case inventoryItemId = "inventory_item_id"
        case addedAt = "added_at"
    }
}
