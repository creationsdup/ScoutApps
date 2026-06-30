import Foundation

/// Entrée du registre de traçabilité alimentaire (table `food_traceability`).
struct FoodTraceEntry: Codable, Identifiable, Hashable {
    let id: String
    var campId: String
    var productName: String
    var brand: String?
    var supplier: String?
    var lotNumber: String?
    var barcode: String?
    var quantity: Double?
    var receivedDate: String?   // "yyyy-MM-dd"
    var expiryDate: String?     // "yyyy-MM-dd"
    var mealId: String?
    var photoPath: String?

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
