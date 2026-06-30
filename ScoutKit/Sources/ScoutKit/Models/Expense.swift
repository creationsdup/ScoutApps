import Foundation

/// Catégorie de dépense (expenses.category).
public enum ExpenseCategory: String, Codable, CaseIterable, Hashable {
    case alimentaire, materiel, transport, autre
    public var label: String {
        switch self {
        case .alimentaire: return "Alimentaire"
        case .materiel:    return "Matériel"
        case .transport:   return "Transport"
        case .autre:       return "Autre"
        }
    }
}

/// Dépense d'un camp (table `expenses`). Prévu vs réel.
public struct Expense: Codable, Identifiable, Hashable {
    public let id: String
    public var campId: String
    public var label: String
    public var category: ExpenseCategory?
    public var amountPlanned: Double?
    public var amountReal: Double?

    public init(
        id: String,
        campId: String,
        label: String,
        category: ExpenseCategory? = nil,
        amountPlanned: Double? = nil,
        amountReal: Double? = nil
    ) {
        self.id = id
        self.campId = campId
        self.label = label
        self.category = category
        self.amountPlanned = amountPlanned
        self.amountReal = amountReal
    }

    enum CodingKeys: String, CodingKey {
        case id
        case campId = "camp_id"
        case label, category
        case amountPlanned = "amount_planned"
        case amountReal = "amount_real"
    }
}
