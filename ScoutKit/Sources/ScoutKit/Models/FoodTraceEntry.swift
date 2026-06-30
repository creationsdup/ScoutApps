import Foundation

/// Entrée du registre de traçabilité alimentaire (table `food_traceability`).
public struct FoodTraceEntry: Codable, Identifiable, Hashable {
    public let id: String
    public var campId: String
    public var productName: String
    public var brand: String?
    public var supplier: String?
    public var lotNumber: String?
    public var barcode: String?
    public var quantity: Double?
    public var receivedDate: String?   // "yyyy-MM-dd"
    public var expiryDate: String?     // "yyyy-MM-dd"
    public var mealId: String?
    public var photoPath: String?

    public init(
        id: String,
        campId: String,
        productName: String,
        brand: String? = nil,
        supplier: String? = nil,
        lotNumber: String? = nil,
        barcode: String? = nil,
        quantity: Double? = nil,
        receivedDate: String? = nil,
        expiryDate: String? = nil,
        mealId: String? = nil,
        photoPath: String? = nil
    ) {
        self.id = id
        self.campId = campId
        self.productName = productName
        self.brand = brand
        self.supplier = supplier
        self.lotNumber = lotNumber
        self.barcode = barcode
        self.quantity = quantity
        self.receivedDate = receivedDate
        self.expiryDate = expiryDate
        self.mealId = mealId
        self.photoPath = photoPath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case productName = "product_name"
        case brand, supplier
        case lotNumber = "lot_number"
        case barcode, quantity
        case receivedDate = "received_date"
        case expiryDate = "expiry_date"
        case mealId = "meal_id"
        case photoPath = "photo_path"
    }
}
