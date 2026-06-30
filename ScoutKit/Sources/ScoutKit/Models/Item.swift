import Foundation

/// Matériel — mappé sur la table `inventory_items` (schéma étendu).
public struct Item: Codable, Identifiable, Hashable {
    public let id: String
    public var inventoryCode: String
    public var name: String
    public var description: String?
    public var categoryId: String?
    public var subcategoryId: String?
    public var locationId: String?
    public var trackingType: TrackingType
    public var quantity: Int            // quantité totale
    public var quantityAvailable: Int?
    public var status: ItemStatus
    public var condition: ItemCondition
    public var branch: Branch?
    public var eventId: String?
    public var imagePath: String?
    public var notes: String?
    public var lastCheckedAt: String?
    public var minimumThreshold: Int?
    public var unit: ItemUnit?

    public init(
        id: String,
        inventoryCode: String,
        name: String,
        description: String? = nil,
        categoryId: String? = nil,
        subcategoryId: String? = nil,
        locationId: String? = nil,
        trackingType: TrackingType,
        quantity: Int,
        quantityAvailable: Int? = nil,
        status: ItemStatus,
        condition: ItemCondition,
        branch: Branch? = nil,
        eventId: String? = nil,
        imagePath: String? = nil,
        notes: String? = nil,
        lastCheckedAt: String? = nil,
        minimumThreshold: Int? = nil,
        unit: ItemUnit? = nil
    ) {
        self.id = id
        self.inventoryCode = inventoryCode
        self.name = name
        self.description = description
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.locationId = locationId
        self.trackingType = trackingType
        self.quantity = quantity
        self.quantityAvailable = quantityAvailable
        self.status = status
        self.condition = condition
        self.branch = branch
        self.eventId = eventId
        self.imagePath = imagePath
        self.notes = notes
        self.lastCheckedAt = lastCheckedAt
        self.minimumThreshold = minimumThreshold
        self.unit = unit
    }

    /// Quantité actuellement sortie (dérivée, non stockée).
    public var quantityOut: Int { max(0, quantity - (quantityAvailable ?? quantity)) }

    /// Stock faible : disponible sous le seuil. N'a de sens que pour le suivi global.
    public var isLowStock: Bool {
        guard trackingType == .global, let threshold = minimumThreshold else { return false }
        return (quantityAvailable ?? quantity) < threshold
    }

    enum CodingKeys: String, CodingKey {
        case id
        case inventoryCode = "inventory_code"
        case name, description
        case categoryId = "category_id"
        case subcategoryId = "subcategory_id"
        case locationId = "location_id"
        case trackingType = "tracking_type"
        case quantity
        case quantityAvailable = "quantity_available"
        case status, condition, branch
        case eventId = "event_id"
        case imagePath = "image_path"
        case notes
        case lastCheckedAt = "last_checked_at"
        case minimumThreshold = "minimum_threshold"
        case unit
    }
}
