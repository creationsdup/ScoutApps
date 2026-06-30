import Foundation

/// Action de mouvement (item_movements.action).
public enum MovementAction: String, Codable, CaseIterable {
    case checkout, `return`, cleaning, repair, transfer
    public var label: String {
        switch self {
        case .checkout: return "Sortir"
        case .return: return "Retour"
        case .cleaning: return "Nettoyage"
        case .repair: return "Réparation"
        case .transfer: return "Transfert"
        }
    }
    /// Statut résultant — source unique action → statut.
    public var nextStatus: ItemStatus {
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
public struct MovementHistory: Codable, Identifiable, Hashable {
    public let id: String
    public var itemId: String
    public var action: MovementAction
    public var userId: String?
    public var eventId: String?
    public var createdAt: String?

    public init(
        id: String,
        itemId: String,
        action: MovementAction,
        userId: String? = nil,
        eventId: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.action = action
        self.userId = userId
        self.eventId = eventId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case action
        case userId = "user_id"
        case eventId = "event_id"
        case createdAt = "created_at"
    }
}
