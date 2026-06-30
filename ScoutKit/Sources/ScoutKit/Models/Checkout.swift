import Foundation

public enum CheckoutStatus: String, Codable, Hashable {
    case open, returned
    public var label: String { self == .open ? "Ouvert" : "Rendu" }
}

public struct Checkout: Codable, Identifiable, Hashable {
    public let id: String
    public var label: String
    public var notes: String?
    public var status: CheckoutStatus
    public var createdAt: String?
    public var returnedAt: String?
    public init(id: String, label: String, notes: String? = nil, status: CheckoutStatus,
                createdAt: String? = nil, returnedAt: String? = nil) {
        self.id = id; self.label = label; self.notes = notes; self.status = status
        self.createdAt = createdAt; self.returnedAt = returnedAt
    }
    enum CodingKeys: String, CodingKey {
        case id, label, notes, status
        case createdAt = "created_at"
        case returnedAt = "returned_at"
    }
}

/// Ligne d'un bon + l'item joint (via inventory_items(*)).
public struct CheckoutLine: Codable, Identifiable, Hashable {
    public let id: String
    public var checkoutId: String
    public var inventoryItemId: String
    public var quantity: Int
    public var quantityReturned: Int
    public var item: Item
    public var remaining: Int { quantity - quantityReturned }
    public init(id: String, checkoutId: String, inventoryItemId: String,
                quantity: Int, quantityReturned: Int, item: Item) {
        self.id = id; self.checkoutId = checkoutId; self.inventoryItemId = inventoryItemId
        self.quantity = quantity; self.quantityReturned = quantityReturned; self.item = item
    }
    enum CodingKeys: String, CodingKey {
        case id
        case checkoutId = "checkout_id"
        case inventoryItemId = "inventory_item_id"
        case quantity
        case quantityReturned = "quantity_returned"
        case item = "inventory_items"
    }
}
