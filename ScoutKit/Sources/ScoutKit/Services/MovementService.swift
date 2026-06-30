import Foundation
import Supabase

/// Enregistre un mouvement de matériel. Pour un rejeu sûr (idempotence), on met à jour
/// le statut (idempotent) AVANT d'insérer le mouvement (journal append-only).
public struct MovementService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    private struct StatusPayload: Encodable { let status: String }
    private struct MovementPayload: Encodable {
        let item_id: String
        let action: String
        let user_id: String
        let event_id: String?
        let quantity: Int?
        let note: String?
    }

    public func record(itemId: String, action: MovementAction, eventId: String? = nil) async throws {
        guard let userId = SupabaseService.shared.currentUserID?.uuidString else {
            throw NSError(domain: "ScoutManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Utilisateur non authentifié."])
        }
        // 1. statut (idempotent)
        try await client.from("inventory_items")
            .update(StatusPayload(status: action.nextStatus.rawValue))
            .eq("id", value: itemId)
            .execute()
        // 2. mouvement (journal)
        try await client.from("item_movements")
            .insert(MovementPayload(item_id: itemId, action: action.rawValue,
                                    user_id: userId, event_id: eventId,
                                    quantity: nil, note: nil))
            .execute()
    }

    /// Enregistre un ajustement de stock dans le journal. NE modifie PAS le statut.
    public func recordAdjustment(itemId: String, quantity: Int, note: String?) async throws {
        guard let userId = SupabaseService.shared.currentUserID?.uuidString else {
            throw NSError(domain: "ScoutManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Utilisateur non authentifié."])
        }
        try await client.from("item_movements")
            .insert(MovementPayload(item_id: itemId, action: MovementAction.adjustment.rawValue,
                                    user_id: userId, event_id: nil,
                                    quantity: quantity, note: note))
            .execute()
    }
}
