import Foundation

/// Action de mouvement (item_movements.action).
enum MovementAction: String, Codable, CaseIterable {
    case checkout, `return`, cleaning, repair, transfer
    var label: String {
        switch self {
        case .checkout: return "Sortir"
        case .return: return "Retour"
        case .cleaning: return "Nettoyage"
        case .repair: return "Réparation"
        case .transfer: return "Transfert"
        }
    }
    /// Statut résultant — source unique action → statut.
    var nextStatus: ItemStatus {
        switch self {
        case .checkout: return .sorti
        case .return: return .disponible
        case .cleaning: return .aVerifier
        case .repair: return .aReparer
        case .transfer: return .disponible
        }
    }
}

/// Mouvement de matériel — mappé sur la table `item_movements`.
struct MovementHistory: Codable, Identifiable, Hashable {
    let id: String
    var itemId: String
    var action: MovementAction
    var userId: String?
    var eventId: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case action
        case userId = "user_id"
        case eventId = "event_id"
        case createdAt = "created_at"
    }
}
