import Foundation
import Supabase

/// Liste de chargement matériel d'un camp + assignation/retour atomiques (RPC).
public struct CampMaterialService {
    public init() {}
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Items du chargement d'un camp (jointure camp_materials -> inventory_items).
    public func items(campId: String) async throws -> [Item] {
        struct Row: Decodable { let inventory_items: Item }
        let rows: [Row] = try await client.from("camp_materials")
            .select("inventory_items(*)").eq("camp_id", value: campId).execute().value
        return rows.map(\.inventory_items)
    }

    public func assign(campId: String, itemId: String) async throws {
        try await client.rpc("assign_material_to_camp",
                             params: ["p_camp_id": campId, "p_item_id": itemId]).execute()
    }
    public func remove(campId: String, itemId: String) async throws {
        try await client.rpc("return_material_from_camp",
                             params: ["p_camp_id": campId, "p_item_id": itemId]).execute()
    }
    public func returnAll(campId: String) async throws {
        for it in try await items(campId: campId) { try await remove(campId: campId, itemId: it.id) }
    }

    /// Nom du camp détenant l'item (pour ScoutMatériel), nil si non emporté.
    public func campLabel(forItemId itemId: String) async throws -> String? {
        struct CampName: Decodable { let name: String }
        struct Row: Decodable { let camps: CampName? }
        let rows: [Row] = try await client.from("camp_materials")
            .select("camps(name)").eq("inventory_item_id", value: itemId).limit(1).execute().value
        return rows.first?.camps?.name
    }
}
