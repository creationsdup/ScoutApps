import Foundation

// Modèles métier — miroir Swift du package `shared` (TypeScript) de CampManager.

enum UserRole: String, Codable {
    case admin, manager, member, viewer

    /// Les rôles autorisés à écrire l'inventaire (cf. can_write_inventory côté SQL).
    var canWrite: Bool {
        switch self {
        case .admin, .manager, .member: return true
        case .viewer: return false
        }
    }
}

enum QrTagStatus: String, Codable {
    case unassigned, assigned, disabled
}

enum ItemCondition: String, Codable {
    case excellent, good, fair, damaged, broken
}

enum ItemStatus: String, Codable {
    case available
    case checkedOut = "checked_out"
    case cleaningRequired = "cleaning_required"
    case repairRequired = "repair_required"
    case missing
    case archived

    var label: String {
        switch self {
        case .available: return "Disponible"
        case .checkedOut: return "Sorti"
        case .cleaningRequired: return "Nettoyage requis"
        case .repairRequired: return "Réparation requise"
        case .missing: return "Manquant"
        case .archived: return "Archivé"
        }
    }
}

enum MovementAction: String, Codable, CaseIterable {
    case checkout
    case `return`
    case cleaning
    case repair
    case transfer

    var label: String {
        switch self {
        case .checkout: return "Sortir"
        case .return: return "Retour"
        case .cleaning: return "Nettoyage"
        case .repair: return "Réparation"
        case .transfer: return "Transfert"
        }
    }
}

/// Source de vérité unique action → statut résultant (miroir de `movementNextStatus`).
enum MovementStatusMapping {
    static func nextStatus(for action: MovementAction) -> ItemStatus {
        switch action {
        case .checkout: return .checkedOut
        case .return: return .available
        case .cleaning: return .cleaningRequired
        case .repair: return .repairRequired
        case .transfer: return .available
        }
    }
}

struct QrTag: Codable, Identifiable {
    let id: String
    let tagCode: String
    let status: QrTagStatus
    let assignedItemId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tagCode = "tag_code"
        case status
        case assignedItemId = "assigned_item_id"
    }
}

struct InventoryItem: Codable, Identifiable, Hashable {
    let id: String
    let inventoryCode: String
    let name: String
    let description: String?
    let condition: ItemCondition
    let status: ItemStatus
    let quantity: Int
    let photoUrl: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case inventoryCode = "inventory_code"
        case name
        case description
        case condition
        case status
        case quantity
        case photoUrl = "photo_url"
        case notes
    }
}

struct Event: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let startDate: String
    let endDate: String
    enum CodingKeys: String, CodingKey {
        case id, name
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

/// Validation du format d'étiquette QR — miroir de `parseTagCode` (TAG-000001).
enum TagCode {
    static func parse(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let pattern = "^TAG-\\d{6}$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return trimmed
    }
}
