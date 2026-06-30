import Foundation
import Supabase

/// Registre de traçabilité d'un camp (table `food_traceability`).
struct FoodTraceService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func list(campId: String) async throws -> [FoodTraceEntry] {
        try await client.from("food_traceability")
            .select().eq("camp_id", value: campId)
            .order("received_date", ascending: false, nullsFirst: false)
            .execute().value
    }

    @discardableResult
    func create(_ entry: FoodTraceEntry) async throws -> FoodTraceEntry {
        try await client.from("food_traceability").insert(entry).select().single().execute().value
    }

    func update(_ entry: FoodTraceEntry) async throws {
        try await client.from("food_traceability").update(entry).eq("id", value: entry.id).execute()
    }

    func delete(id: String) async throws {
        try await client.from("food_traceability").delete().eq("id", value: id).execute()
    }
}
