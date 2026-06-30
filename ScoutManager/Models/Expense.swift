import Foundation

/// Catégorie de dépense (expenses.category).
enum ExpenseCategory: String, Codable, CaseIterable, Hashable {
    case alimentaire, materiel, transport, autre
    var label: String {
        switch self {
        case .alimentaire: return "Alimentaire"
        case .materiel:    return "Matériel"
        case .transport:   return "Transport"
        case .autre:       return "Autre"
        }
    }
}

/// Dépense d'un camp (table `expenses`). Prévu vs réel.
struct Expense: Codable, Identifiable, Hashable {
    let id: String
    var campId: String
    var label: String
    var category: ExpenseCategory?
    var amountPlanned: Double?
    var amountReal: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case label, category
        case amountPlanned = "amount_planned"
        case amountReal = "amount_real"
    }
}
