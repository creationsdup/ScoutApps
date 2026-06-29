import Foundation

/// Matériel — mappé sur la table `inventory_items` (schéma étendu).
struct Item: Codable, Identifiable, Hashable {
    let id: String
    var inventoryCode: String
    var name: String
    var description: String?
    var categoryId: String?
    var locationId: String?
    var trackingType: TrackingType
    var quantity: Int            // quantité totale
    var quantityAvailable: Int?
    var status: ItemStatus
    var condition: ItemCondition
    var branch: Branch?
    var eventId: String?
    var imagePath: String?
    var notes: String?
    var lastCheckedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case inventoryCode = "inventory_code"
        case name, description
        case categoryId = "category_id"
        case locationId = "location_id"
        case trackingType = "tracking_type"
        case quantity
        case quantityAvailable = "quantity_available"
        case status, condition, branch
        case eventId = "event_id"
        case imagePath = "image_path"
        case notes
        case lastCheckedAt = "last_checked_at"
    }
}
