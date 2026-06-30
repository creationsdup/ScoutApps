import Foundation
import Supabase

/// Accès aux créneaux de planning (program_slots) et au lien matériel (program_slot_materials).
public struct ProgramService {
    public init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Slots

    public func list(campId: String) async throws -> [ProgramSlot] {
        try await client.from("program_slots")
            .select()
            .eq("camp_id", value: campId)
            .order("date")
            .order("start_time")
            .execute().value
    }

    @discardableResult
    public func create(_ slot: ProgramSlot) async throws -> ProgramSlot {
        try await client.from("program_slots")
            .insert(slot).select().single().execute().value
    }

    public func update(_ slot: ProgramSlot) async throws {
        try await client.from("program_slots")
            .update(slot).eq("id", value: slot.id).execute()
    }

    public func delete(id: String) async throws {
        try await client.from("program_slots").delete().eq("id", value: id).execute()
    }

    // MARK: - Material link (program_slot_materials)

    /// Identifiants des items liés à un créneau.
    public func itemIds(slotId: String) async throws -> [String] {
        struct Row: Decodable { let inventory_item_id: String }
        let rows: [Row] = try await client.from("program_slot_materials")
            .select("inventory_item_id")
            .eq("slot_id", value: slotId)
            .execute().value
        return rows.map(\.inventory_item_id)
    }

    /// Remplace tous les items liés à un créneau par l'ensemble fourni.
    public func setItems(slotId: String, itemIds: [String]) async throws {
        struct Link: Encodable {
            let slot_id: String
            let inventory_item_id: String
        }
        try await client.from("program_slot_materials")
            .delete().eq("slot_id", value: slotId).execute()
        if !itemIds.isEmpty {
            let links = itemIds.map { Link(slot_id: slotId, inventory_item_id: $0) }
            try await client.from("program_slot_materials").insert(links).execute()
        }
    }
}
